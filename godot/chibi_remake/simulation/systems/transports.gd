extends RefCounted
## 船员关联为权威状态；人数/兵力为派生汇总，不作为载员身份来源。
const CAPACITY:=16
const SHIP:=47
const NAVAL:=[46,47,48,49,52]
const TechnologyState = preload("res://simulation/systems/technology_state.gd")
const Footprint = preload("res://simulation/systems/unit_footprint.gd")
const Access = preload("res://simulation/ports/transports_access.gd")
var host: Access

func _init(h: Object) -> void:
	host = h.simulation_access("transports") if h.has_method("simulation_access") else h

func valid_unit(unit: Dictionary) -> bool:
	return not unit.is_empty() and host.units.any(func(u):return is_same(u,unit)) and bool(unit.get("alive",false)) and float(unit.get("die_t",-1))<0

func valid_ship(ship: Dictionary) -> bool:
	return valid_unit(ship) and int(ship.unit)==SHIP and not bool(ship.get("attached",false))

func passengers(ship: Dictionary) -> Array:
	return host.units.filter(func(u):return bool(u.get("alive",false)) and float(u.get("die_t",-1))<0 and bool(u.get("attached",false)) and int(u.get("aboard_uid",-1))==int(ship.uid))

func ship_for(unit: Dictionary) -> Dictionary:
	var uid:=int(unit.get("aboard_uid",-1))
	for ship in host.units:
		if int(ship.uid)==uid and int(ship.unit)==SHIP:return ship
	return {}

func reconcile() -> void:
	var totals:={}
	for unit in host.units:
		if not bool(unit.get("attached",false)):continue
		if not bool(unit.alive) or float(unit.die_t)>=0:
			unit.aboard_uid=-1;continue # 隐藏的死亡对象不保留船引用。
		var uid:=int(unit.get("aboard_uid",-1))
		if not totals.has(uid):totals[uid]={"n":0,"hp":0.0}
		totals[uid].n+=1;totals[uid].hp+=float(unit.hp)
	for ship in host.units:
		if int(ship.unit)!=SHIP:continue
		var total: Dictionary=totals.get(int(ship.uid),{"n":0,"hp":0.0})
		ship.carry_n=int(total.n);ship.carry_hp=float(total.hp);ship.loaded=int(total.n)>0

func restore(version: int) -> void:
	if version<8:
		for unit in host.units:
			if bool(unit.get("attached",false)) and bool(unit.alive) and float(unit.die_t)<0:
				host._cancel_unit_command(unit);unit.state="boarded"
	reconcile()

func landing_cell(ship: Dictionary, unit: Dictionary = {}) -> Vector2i:
	for cell in coastal_anchors(ship,int(unit.get("unit",-1))):
		if host._unit_placement_free(cell,int(unit.get("unit",-1)),0,int(unit.get("uid",-1))):return cell
	return Vector2i(-1,-1)

func edge_distance_at(anchor: Vector2i, unit_id: int, ship: Dictionary) -> int:
	var best:=2147483647
	for own_cell in Footprint.shape(unit_id,anchor):
		for ship_cell in host._footprint_cells(ship):
			best=mini(best,maxi(absi(own_cell.x-ship_cell.x),absi(own_cell.y-ship_cell.y)))
	return best

func adjacent(unit: Dictionary, ship: Dictionary) -> bool:
	return edge_distance_at(host._unit_cell(unit),int(unit.unit),ship)==1

## Invert the unit's footprint offsets against the ship's eight-neighbor border.
## This covers large passengers without searching unrelated distant land rings.
func coastal_anchors(ship: Dictionary, unit_id: int) -> Array:
	var candidates:Dictionary={}
	for ship_cell in host._footprint_cells(ship):
		for dx in range(-1,2):
			for dy in range(-1,2):
				if dx==0 and dy==0:continue
				var border:Vector2i=ship_cell+Vector2i(dx,dy)
				for parity in range(2):
					for offset in Footprint.offsets(Footprint.class_of(unit_id),parity):
						var anchor:Vector2i=border-offset
						if (anchor.y&1)!=parity or candidates.has(anchor):continue
						if anchor.x<0 or anchor.y<0 or anchor.x>=int(host.map_data.rows) or anchor.y>=int(host.map_data.cols):continue
						if edge_distance_at(anchor,unit_id,ship)!=1:continue
						var clear:=true
						for cell in Footprint.shape(unit_id,anchor):
							if cell.x<0 or cell.y<0 or cell.x>=int(host.map_data.rows) or cell.y>=int(host.map_data.cols) or host.nav.is_water(cell) or host.nav.is_solid(cell,0):clear=false;break
						if clear:candidates[anchor]=true
	var ordered:Array=candidates.keys()
	var center:=Vector2(float(ship.ax),float(ship.ay))
	ordered.sort_custom(func(a,b):
		var da:float=host.nav.anchor_of(a.x,a.y).distance_squared_to(center)
		var db:float=host.nav.anchor_of(b.x,b.y).distance_squared_to(center)
		return (a.y<b.y if a.y!=b.y else a.x<b.x) if is_equal_approx(da,db) else da<db)
	return ordered

func boarding_path(unit: Dictionary, ship: Dictionary) -> Array:
	var anchors:=coastal_anchors(ship,int(unit.unit))
	var origin:=Vector2(float(unit.ax),float(unit.ay))
	anchors.sort_custom(func(a,b):
		var da:float=host.nav.anchor_of(a.x,a.y).distance_squared_to(origin)
		var db:float=host.nav.anchor_of(b.x,b.y).distance_squared_to(origin)
		return (a.y<b.y if a.y!=b.y else a.x<b.x) if is_equal_approx(da,db) else da<db)
	for anchor in anchors:
		if not host._unit_placement_free(anchor,int(unit.unit),0,int(unit.uid)):continue
		var path:Array=host._path_to(unit,host.nav.anchor_of(anchor.x,anchor.y),false)
		if not path.is_empty():return path
	return []

static func integer(value: Variant, minimum: int=0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<=2147483647

func valid_snapshot(ids: Dictionary, version: int) -> bool:
	var totals:={}
	for uid in ids:
		var unit: Dictionary=ids[uid];var state: Dictionary=unit.simulation
		if str(unit.get("state",""))=="unload" and (int(unit.unit)!=SHIP or bool(state.get("attached",false))):return false
		for field in ["attached","loaded"]:
			if state.has(field) and not state[field] is bool and not (state[field]==null and version<8):return false
		# R03：卸载状态与节拍相位必须是合法结构；旧档缺字段按未卸载迁移。
		var unload_active=state.get("unload_active",false);var unload_t=state.get("unload_t",0)
		if unload_active==null:unload_active=false
		if unload_t==null:unload_t=0
		if not unload_active is bool or not integer(unload_t):return false
		if bool(unload_active) or str(unit.get("state",""))=="unload":
			if int(unit.unit)!=SHIP or bool(unit.building) or bool(state.get("attached",false)):return false
			if not bool(unit.alive) or float(unit.dieT)>=0:return false
		elif int(unit.unit)!=SHIP and (bool(unload_active) or int(unload_t)!=0):return false
		var aboard=state.get("aboard_uid",-1);var count=state.get("carry_n",0);var hp=state.get("carry_hp",0)
		if version<8:
			if aboard==null:aboard=-1
			if count==null:count=0
			if hp==null:hp=0
		if not integer(aboard,-1) or not integer(count) or int(count)>CAPACITY:return false
		if not (hp is int or hp is float) or not is_finite(float(hp)) or float(hp)<0:return false
		if int(unit.unit)!=SHIP and (int(count)!=0 or float(hp)!=0 or bool(state.get("loaded",false))):return false
		if not bool(state.get("attached",false)):
			if int(aboard)!=-1:return false
			continue
		if bool(unit.building) or int(unit.unit) in NAVAL:return false
		if not bool(unit.alive) or float(unit.dieT)>=0:
			if version>=8 and int(aboard)!=-1:return false
			continue # 旧版沉船遗留的隐藏尸体在恢复时清船引用。
		if int(aboard)==int(uid) or not ids.has(int(aboard)):return false
		var ship: Dictionary=ids[int(aboard)]
		if int(ship.unit)!=SHIP or int(ship.owner)!=int(unit.owner) or not bool(ship.alive) or float(ship.dieT)>=0 or bool(ship.simulation.get("attached",false)):return false
		if version>=8 and str(unit.get("state",""))!="boarded":return false
		var life=unit.get("hp",-1);var maximum=state.get("maxhp",life)
		if not (life is int or life is float) or not is_finite(float(life)) or float(life)<0:return false
		if not (maximum is int or maximum is float) or not is_finite(float(maximum)) or float(maximum)<0:return false
		# R01：科技允许普通部队“当前 HP 高于基础上限”（technology.gd 保留这一契约）。
		# 载员校验因此不能再用 hp <= maxhp，而要用统一的可接受上限：
		# 基础上限 + 科技累计获得的当前兵力（每级 400，最高 3 级 = 1200）。
		if maximum==null:maximum=life
		var base=state.get("base_maxhp",maximum);var bonus=state.get("tech_hp_bonus",0)
		if base==null:base=maximum
		if bonus==null:bonus=0
		if not TechnologyState.valid_hp(life,maximum,base,bonus):return false
		if not totals.has(int(aboard)):totals[int(aboard)]={"n":0,"hp":0.0}
		totals[int(aboard)].n+=1;totals[int(aboard)].hp+=float(life)
		if int(totals[int(aboard)].n)>CAPACITY:return false
	for uid in ids:
		var unit: Dictionary=ids[uid]
		if int(unit.unit)!=SHIP:continue
		var state: Dictionary=unit.simulation;var total: Dictionary=totals.get(uid,{"n":0,"hp":0.0})
		if version>=8 and (int(state.get("carry_n",0))!=int(total.n) or absf(float(state.get("carry_hp",0))-float(total.hp))>0.00001 or bool(state.get("loaded",false))!=(int(total.n)>0)):return false
	return true
