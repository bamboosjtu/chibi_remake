extends RefCounted
## Ground-cell effect 7, separate from a unit's legacy burn timer.
const LIMIT := 100
const Access = preload("res://simulation/ports/fire_fields_access.gd")
var host: Access
var active:Array=[]
func _init(battle:Object) -> void:host = battle.simulation_access("fire_fields") if battle.has_method("simulation_access") else battle

func ignite(point:Vector2) -> bool:
	if active.size()>=LIMIT:return false
	var cell:Vector2i=host._cell_of_px(point.x,point.y)
	if cell.x<0 or cell.y<0 or cell.x>=int(host.map_data.rows) or cell.y>=int(host.map_data.cols):return false
	active.append({"a":cell.x,"b":cell.y,"age":0})
	return true

func step() -> void:
	var survivors:Array=[]
	for fire in active:
		fire.age=int(fire.age)+1
		if int(fire.age)>=5 and (int(fire.age)-5)%4==0:
			var cell:=Vector2i(int(fire.a),int(fire.b))
			for target in host.units:
				if not bool(target.alive) or float(target.die_t)>=0 or bool(target.get("attached",false)) or int(target.get("site_inside_uid",-1))>=0:continue
				if cell not in host._footprint_cells(target):continue
				host._apply_hit(target,10.0,-1)
				break
		if int(fire.age)<100:survivors.append(fire)
	active=survivors

func snapshot() -> Array:return active.duplicate(true)
func valid_snapshot(value:Variant) -> bool:
	if not value is Array or value.size()>LIMIT:return false
	for fire in value:
		if not fire is Dictionary:return false
		for key in ["a","b","age"]:
			var v=fire.get(key)
			var cap:int=int(host.map_data.rows) if key=="a" else (int(host.map_data.cols) if key=="b" else 100)
			if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=floorf(float(v)) or float(v)<0 or float(v)>=cap:return false
	return true
func restore(value:Array) -> void:active=value.duplicate(true)
