extends Object
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
## spatial index: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
var battle: State
var _dep_abilities: Object
var _dep_battle_simulation: Object
var _dep_command_groups: Object
var _dep_interaction_paths: Object
var _position_cells: Dictionary={}
var _geometry_revision := -1
const TRANSIT_STATES := ["move","gather","deliver","join","build","repair","board","unload"]
const CLOSE_WORK_STATES := ["gather","deliver","build"]

func _init(data: State) -> void:
	battle = data

func _unit_cell(u: Dictionary) -> Vector2i:
	var uid:=int(u.get("uid",-1))
	if uid<0:return _nav.cell_of_px(float(u.ax),float(u.ay))
	if _geometry_revision!=_nav.state.geometry_revision:
		_position_cells.clear();_geometry_revision=_nav.state.geometry_revision
	var px:=float(u.ax);var py:=float(u.ay);var previous=_position_cells.get(uid)
	if previous!=null and previous.x==px and previous.y==py:return previous.cell
	var cell:=_nav.cell_of_px(px,py)
	_position_cells[uid]={"x":px,"y":py,"cell":cell}
	return cell

func _unit_overlaps_other(u: Dictionary) -> bool:
	_index_ensure_current()
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null:return kernel.overlaps(u,battle._cell_index,_nav.native_query_context())
	return _unit_overlaps_other_script(u)

func _unit_overlaps_other_script(u: Dictionary) -> bool:
	_index_ensure_current()
	var uid:=int(u.uid);var layer:=int(battle._cell_index_layer.get(uid,-1))
	if layer<0 or int(battle._index_unit_id.get(uid,-1))!=int(u.unit):layer=_dep_command_groups._nav_layer(u)
	var table: Dictionary=battle._cell_index.get(layer,{})
	if preload("res://simulation/navigation/unit_footprint.gd").class_of(int(u.unit))==0:
		var single=table.get(_unit_cell(u))
		return single!=null and (single.size()>1 or not single.has(uid))
	for cell in _dep_interaction_paths._footprint_cells(u):
		var bucket=table.get(cell)
		if bucket!=null and (bucket.size()>1 or not bucket.has(uid)):return true
	return false

func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	_index_ensure_current()
	if layer >= 0:
		return _cell_unit_in(layer, cell, exclude_uid)
	for key in battle._cell_index:
		var found := _cell_unit_in(int(key), cell, exclude_uid)
		if not found.is_empty():
			return found
	return {}

func _cell_unit_in(layer: int, cell: Vector2i, exclude_uid: int) -> Dictionary:
	var table: Dictionary = battle._cell_index.get(layer, {})
	if table.is_empty(): return {}
	var bucket = table.get(cell, null)
	if not bucket is Dictionary: return {}
	for uid in bucket:
		if int(uid) == exclude_uid: continue
		return bucket[uid]
	return {}

func nearby_units(first: Vector2i, second: Vector2i, radius: int, layer: int) -> Array:
	_index_ensure_current()
	var table: Dictionary = battle._cell_index.get(layer, {})
	if table.is_empty(): return []
	var rows := int(battle.map_data.rows)
	var cols := int(battle.map_data.cols)
	var found := {}
	for center: Vector2i in [first, second]:
		var y_min := maxi(0, center.y - radius)
		var y_end := mini(cols, center.y + radius + 1)
		for x in range(maxi(0, center.x - radius), mini(rows, center.x + radius + 1)):
			for y in range(y_min, y_end):
				var bucket = table.get(Vector2i(x, y))
				if bucket == null: continue
				for uid in bucket:
					found[uid] = bucket[uid]
	return found.values()

func _index_eligible(u: Dictionary) -> bool:
	if u == null: return false
	return int(u.get("site_inside_uid", -1)) < 0 and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0 \
			and not bool(u.get("is_building", false)) and not bool(u.get("attached", false))

func _index_forget(u: Dictionary) -> void:
	var uid := int(u.get("uid", -1))
	if not _index_eligible(u):_position_cells.erase(uid)
	if not battle._cell_index_cells.has(uid): return
	var layer := int(battle._cell_index_layer.get(uid, 0))
	var table: Dictionary = battle._cell_index.get(layer, {})
	for raw in battle._cell_index_cells[uid]:
		var bucket = table.get(raw, null)
		if not bucket is Dictionary: continue
		bucket.erase(uid)
		if bucket.is_empty():
			table.erase(raw)
	battle._cell_index_cells.erase(uid)
	battle._cell_index_layer.erase(uid)
	battle._cell_index_cell.erase(uid)
	battle._index_unit_id.erase(uid)

func _index_remember(u: Dictionary) -> void:
	if not _index_eligible(u): return
	var uid := int(u.get("uid", -1))
	if uid < 0: return
	var anchor := _unit_cell(u)
	var layer: int = _dep_command_groups._nav_layer(u)
	var cells: Array = _dep_interaction_paths._footprint_cells(u)
	var table: Dictionary = battle._cell_index.get(layer, {})
	for raw in cells:
		var bucket = table.get(raw, null)
		if not bucket is Dictionary:
			bucket = {}
			table[raw] = bucket
		bucket[uid] = u
	battle._cell_index[layer] = table
	battle._cell_index_cell[uid] = anchor
	battle._cell_index_layer[uid] = layer
	battle._cell_index_cells[uid] = cells
	battle._index_unit_id[uid] = int(u.get("unit", -1))

func _index_sync(u: Dictionary) -> void:
	var uid := int(u.get("uid", -1))
	if uid < 0: return
	if not _index_eligible(u):
		_index_forget(u)
		return
	var anchor := _unit_cell(u)
	var layer: int = _dep_command_groups._nav_layer(u)
	if battle._cell_index_cell.get(uid, null) == anchor and int(battle._cell_index_layer.get(uid, -2)) == layer \
			and int(battle._index_unit_id.get(uid, -2)) == int(u.get("unit", -1)):
		return
	_index_forget(u)
	_index_remember(u)

func _target_sync(u: Dictionary) -> void:
	if u == null: return
	var uid := int(u.get("uid", -1))
	if uid < 0: return
	var owner := int(u.get("owner", -1))
	var known = battle._target_owner.get(uid, null)
	var tracked := int(u.get("site_inside_uid", -1)) < 0 and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0 \
			and not bool(u.get("attached", false)) and owner > 0
	if not tracked:
		if known != null:
			battle._targets[int(known)].erase(uid)
			battle._target_owner.erase(uid)
		return
	if known != null and int(known) == owner:
		return                    # 归属未变：同一字典引用仍在桶里
	if known != null:
		battle._targets[int(known)].erase(uid)
	if not battle._targets.has(owner):
		battle._targets[owner] = {}
	battle._targets[owner][uid] = u
	battle._target_owner[uid] = owner

func _target_forget(u: Dictionary) -> void:
	var uid := int(u.get("uid", -1))
	var known = battle._target_owner.get(uid, null)
	if known != null:
		battle._targets[int(known)].erase(uid)
		battle._target_owner.erase(uid)

func _index_ensure_current() -> void:
	if is_same(battle.units, battle._index_units_ref) and battle.units.size() == battle._index_units_size:
		return
	_rebuild_unit_index()

func _contains_unit(unit: Dictionary) -> bool:
	_index_ensure_current()
	var uid := int(unit.get("uid", -1))
	var owner = battle._target_owner.get(uid)
	if owner != null: return is_same(battle._targets[int(owner)].get(uid), unit)
	# Neutral resources and temporarily hidden units are not in target buckets.
	return battle.units.any(func(other): return is_same(other, unit))

func _rebuild_unit_index() -> void:
	_position_cells.clear()
	battle._index_units_ref = battle.units
	battle._index_units_size = battle.units.size()
	battle._cell_index.clear()
	battle._cell_index_cell.clear()
	battle._cell_index_layer.clear()
	battle._cell_index_cells.clear()
	battle._index_unit_id.clear()
	battle._foot_cache.clear()
	battle._targets.clear()
	battle._target_owner.clear()
	for u in battle.units:
		_index_remember(u)
		_target_sync(u)

func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	_index_ensure_current()
	var cls:=preload("res://simulation/navigation/unit_footprint.gd").class_of(unit_id)
	if not _nav._anchor_fits(anchor,layer,cls):return false
	var table: Dictionary=battle._cell_index.get(layer,{})
	for offset in preload("res://simulation/navigation/unit_footprint.gd").offsets(cls,anchor.y):
		var cell: Vector2i=anchor+offset
		if layer<0:
			if not _cell_unit(cell,exclude_uid,layer).is_empty():return false
		else:
			var bucket=table.get(cell)
			if bucket!=null and (bucket.size()>1 or not bucket.has(exclude_uid)):return false
	return true

func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	for r in range(0, mini(12, max_radius) + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and maxi(absi(dx), absi(dy)) != r: continue
				var c := Vector2i(clampi(cell.x + dx, 0, int(battle.map_data.rows) - 1), clampi(cell.y + dy, 0, int(battle.map_data.cols) - 1))
				if _unit_placement_free(c, unit_id, layer, exclude_uid): return c
	return Vector2i(-1, -1)

func _separate_unit(u: Dictionary) -> void:
	if preload("res://simulation/combat/stratagem_rules.gd").active(u):return
	if int(u.get("site_inside_uid", -1)) >= 0: return
	if not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0: return
	if bool(u.get("is_building", false)) or bool(u.get("attached", false)): return
	var st := str(u.get("state", ""))
	# 采集/运货到达目标后仍不能叠格；路线尚未走完时允许穿过拥挤中间格，
	# 否则后处理会每帧把工人推回原点，形成“有路径但永远到不了”的死循环。
	if st in TRANSIT_STATES and not (u.get("path", []) as Array).is_empty(): return
	if not _unit_overlaps_other(u): return
	var cell := _unit_cell(u)
	# 采集/运货/施工只在相邻一格内让位；否则会被推到很远，反而走不回目标。
	var near_only := st in CLOSE_WORK_STATES
	# R05：让位格必须与当前格**连通**。直接使用 _free_unit_cell 会在完全被墙围住时
	# 把单位瞬移到墙外（评审夹具：一圈封锁后位移约 90.7px，实际无路可走）。
	var free := _connected_separation_cell(u, cell, near_only)
	if free.x < 0: return
	var p := _nav.anchor_of(free.x, free.y)
	# Yield at walking speed; snapping to a free cell caused visible sideways hops.
	var previous:=Vector2(float(u.ax),float(u.ay))
	var next:=previous.move_toward(p,Config.SPEED*_dep_abilities._spd_mult(u)*Config.SIM_DT)
	u.ax=next.x;u.ay=next.y
	var actual:=_unit_cell(u);u.A=actual.x;u.B=actual.y
	u.moved=not next.is_equal_approx(previous)
	if u.moved:u.dir=int(round((next-previous).angle()/(PI/4.0)))&7
	u.path = []; u.pi = 0
	_dep_battle_simulation._place_unit(u)

func _connected_separation_cell(u: Dictionary, cell: Vector2i, near_only: bool) -> Vector2i:
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null:
		var cursor:=0;var context:=_nav.native_query_context()
		while true:
			var candidate: Vector4i=kernel.separation_candidate(u,battle._cell_index,context,near_only,cursor)
			if candidate.x<0:return Vector2i(-1,-1)
			cursor=candidate.w
			var result:=Vector2i(candidate.x,candidate.y)
			if candidate.z<=1 or not _nav.find_path(Vector2(u.ax,u.ay),_nav.anchor_of(result.x,result.y),true,_dep_command_groups._nav_layer(u),int(u.owner),int(u.unit)).is_empty():return result
	return _connected_separation_cell_script(u,cell,near_only)

func _connected_separation_cell_script(u: Dictionary, cell: Vector2i, near_only: bool) -> Vector2i:
	var layer: int = _dep_command_groups._nav_layer(u)
	var uid := int(u.get("uid", -1))
	var unit_id := int(u.get("unit", -1))
	var origin := Vector2(float(u.ax), float(u.ay))
	var max_radius := 1 if near_only else 12
	var unit_cls := preload("res://simulation/navigation/unit_footprint.gd").class_of(unit_id)
	for r in range(1, max_radius + 1):
		# 同一圈内按固定扫描顺序，保证结果与帧率无关。
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(clampi(cell.x + dx, 0, int(battle.map_data.rows) - 1),
					clampi(cell.y + dy, 0, int(battle.map_data.cols) - 1))
				if c == cell or not _unit_placement_free(c, unit_id, layer, uid):
					continue
				var p := _nav.anchor_of(c.x, c.y)
				# 相邻格用视线校验（便宜，多格单位按整块扫掠）；更远的格必须真的有路。
				if unit_cls > 0:
					if not _nav.body_segment_clear_from(origin, p, layer, unit_cls):
						continue
				elif not _nav.segment_clear_from(origin, p, layer):
					continue
				if r > 1 and _nav.find_path(origin, p, true, layer, int(u.get("owner", -1)), unit_id).is_empty():
					continue
				return c
	return Vector2i(-1, -1)

## Projectile arrivals and kill rewards resolve one UID, not a filtered copy of
## the whole army. Neutral, dying and attached records retain the legacy lookup.
func unit_by_uid(uid: int) -> Dictionary:
	_index_ensure_current()
	var owner=battle._target_owner.get(uid)
	if owner!=null:
		var found: Dictionary=battle._targets[int(owner)].get(uid,{})
		if not found.is_empty() and int(found.uid)==uid:return found
	for unit: Dictionary in battle.units:
		if int(unit.uid)==uid:return unit
	return {}

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_battle_simulation = world.battle_simulation
	_dep_command_groups = world.command_groups
	_dep_interaction_paths = world.interaction_paths
	_nav = world.nav
