extends RefCounted
## spatial index: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/spatial_index_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _unit_cell(u: Dictionary) -> Vector2i:
	return battle.nav.cell_of_px(float(u.ax), float(u.ay))

func _unit_overlaps_other(u: Dictionary) -> bool:
	for raw in ports._footprint_cells(u):
		var c: Vector2i = raw
		if not _cell_unit(c, int(u.get("uid", -1)), ports._nav_layer(u)).is_empty():
			return true
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

func _index_eligible(u: Dictionary) -> bool:
	if u == null: return false
	return int(u.get("site_inside_uid", -1)) < 0 and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0 \
			and not bool(u.get("is_building", false)) and not bool(u.get("attached", false))

func _index_forget(u: Dictionary) -> void:
	var uid := int(u.get("uid", -1))
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
	var layer := ports._nav_layer(u)
	var cells := ports._footprint_cells(u)
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
	var layer := ports._nav_layer(u)
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
	for raw in preload("res://simulation/systems/unit_footprint.gd").shape(unit_id, anchor):
		var c: Vector2i = raw
		if c.x < 0 or c.y < 0 or c.x >= int(battle.map_data.rows) or c.y >= int(battle.map_data.cols): return false
		if battle.nav.is_solid(c, layer): return false
		if not _cell_unit(c, exclude_uid, layer).is_empty(): return false
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
	if battle.stratagems.active(u):return
	if int(u.get("site_inside_uid", -1)) >= 0: return
	if not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0: return
	if bool(u.get("is_building", false)) or bool(u.get("attached", false)): return
	var st := str(u.get("state", ""))
	# 采集/运货到达目标后仍不能叠格；路线尚未走完时允许穿过拥挤中间格，
	# 否则后处理会每帧把工人推回原点，形成“有路径但永远到不了”的死循环。
	if st in ["move", "gather", "deliver", "join", "build", "repair", "board", "unload"] and not (u.get("path", []) as Array).is_empty(): return
	if not _unit_overlaps_other(u): return
	var cell := _unit_cell(u)
	# 采集/运货/施工只在相邻一格内让位；否则会被推到很远，反而走不回目标。
	var near_only := st in ["gather", "deliver", "build"]
	# R05：让位格必须与当前格**连通**。直接使用 _free_unit_cell 会在完全被墙围住时
	# 把单位瞬移到墙外（评审夹具：一圈封锁后位移约 90.7px，实际无路可走）。
	var free := _connected_separation_cell(u, cell, near_only)
	if free.x < 0: return
	var p := battle.nav.anchor_of(free.x, free.y)
	# Yield at walking speed; snapping to a free cell caused visible sideways hops.
	var previous:=Vector2(float(u.ax),float(u.ay))
	var next:=previous.move_toward(p,Config.SPEED*ports._spd_mult(u)*Config.SIM_DT)
	u.ax=next.x;u.ay=next.y
	var actual:=_unit_cell(u);u.A=actual.x;u.B=actual.y
	u.moved=not next.is_equal_approx(previous)
	if u.moved:u.dir=int(round((next-previous).angle()/(PI/4.0)))&7
	u.path = []; u.pi = 0
	ports._place_unit(u)

func _connected_separation_cell(u: Dictionary, cell: Vector2i, near_only: bool) -> Vector2i:
	var layer := ports._nav_layer(u)
	var uid := int(u.get("uid", -1))
	var unit_id := int(u.get("unit", -1))
	var origin := Vector2(float(u.ax), float(u.ay))
	var max_radius := 1 if near_only else 12
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
				var p := battle.nav.anchor_of(c.x, c.y)
				# 相邻格用视线校验（便宜，多格单位按整块扫掠）；更远的格必须真的有路。
				var unit_cls := preload("res://simulation/systems/unit_footprint.gd").class_of(unit_id)
				if unit_cls > 0:
					if not battle.nav.body_segment_clear_from(origin, p, layer, unit_cls):
						continue
				elif not battle.nav.segment_clear_from(origin, p, layer):
					continue
				if r > 1 and battle.nav.find_path(origin, p, true, layer, int(u.get("owner", -1)), unit_id).is_empty():
					continue
				return c
	return Vector2i(-1, -1)
