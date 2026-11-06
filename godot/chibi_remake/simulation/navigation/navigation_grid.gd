extends RefCounted
## navigation grid.
const GridState = preload("res://simulation/navigation/navigation_state.gd")
var _grid_state: GridState
var ports = preload("res://simulation/ports/navigation_grid_dependencies.gd").new()
const UnitFootprint = preload("res://simulation/systems/unit_footprint.gd")

func _init(data: GridState) -> void:
	_grid_state = data

func setup(md: Dictionary) -> void:
	_grid_state.version += 1                   # 整图重建（开局/读档 rebuild_buildings）也是一次阻挡变更
	_grid_state.map_data = md
	_grid_state.tile_w = float(_grid_state.map_data.get("tileW", 44))
	_grid_state.tile_hw = _grid_state.tile_w * 0.5
	_grid_state.tile_hh = _grid_state.tile_w * 0.25
	var rows := int(_grid_state.map_data.rows)
	var cols := int(_grid_state.map_data.cols)
	_grid_state.astar.clear()
	_grid_state.water_astar.clear()
	_grid_state.occupancy.clear()
	_grid_state.gates.clear()
	_grid_state.gate_cells.clear()
	_grid_state.blocked_cells.clear()
	_grid_state.resource_cells.clear()
	# R04：整图重建后按需重建形状图（旧图里的点位/禁用状态已失效）。
	_grid_state._shape_graphs.clear()
	_grid_state._shape_pending.clear()
	for a in range(rows):
		for b in range(cols):
			var pos := anchor_of(a, b)
			_grid_state.astar.add_point(_id(Vector2i(a, b)), pos)
			_grid_state.water_astar.add_point(_id(Vector2i(a, b)), pos)
	for a in range(rows):
		for b in range(cols):
			var c := Vector2i(a, b)
			for neighbor in neighbors(c):
				if not _grid_state.astar.are_points_connected(_id(c), _id(neighbor)):
					_grid_state.astar.connect_points(_id(c), _id(neighbor))
				if not _grid_state.water_astar.are_points_connected(_id(c), _id(neighbor)):
					_grid_state.water_astar.connect_points(_id(c), _id(neighbor))
	var walk: Array = _grid_state.map_data.get("terrainWalkable", _grid_state.map_data.walkable)
	for i in range(walk.size()):
		if int(walk[i]) == 0:
			_grid_state.astar.set_point_disabled(i, true)
	# 水面层：没有 waterWalkable 数据、或整张图没有一格水面的（纯陆战图）→ 整层关闭，
	# 调用方 `_nav_layer` 自动退回陆地层。
	var water: Array = _grid_state.map_data.get("waterWalkable", [])
	_grid_state.has_water = water.size() == walk.size()
	if _grid_state.has_water:
		var water_n := 0
		for i in range(water.size()):
			if int(water[i]) == 0:
				_grid_state.water_astar.set_point_disabled(i, true)
			else:
				water_n += 1
		_grid_state.has_water = water_n > 0

func _id(c: Vector2i) -> int:
	return c.x * int(_grid_state.map_data.cols) + c.y

func _cell_of_id(id: int) -> Vector2i:
	var cols := int(_grid_state.map_data.cols)
	return Vector2i(id / cols, id % cols)

func _grid(layer: int) -> AStar2D:
	return _grid_state.water_astar if layer == 1 and _grid_state.has_water else _grid_state.astar

func neighbors(c: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in [-1, 1]:
		for dx in [0, 1 if c.y & 1 else -1]:
			var p := c + Vector2i(dx, dy)
			if p.x >= 0 and p.x < int(_grid_state.map_data.rows) and p.y >= 0 and p.y < int(_grid_state.map_data.cols):
				result.append(p)
	return result

# ------------------------------------------------------------- 坐标换算 ----
## 屏幕像素 → 等距格（越界坐标会 clamp 到地图内）

func cell_of_px(px: float, py: float) -> Vector2i:
	var b := int(round((py - _grid_state.tile_hw) / _grid_state.tile_hh))
	var a := int(round((px - _grid_state.tile_hw - _grid_state.tile_hw * float(b & 1)) / _grid_state.tile_w))
	a = clampi(a, 0, int(_grid_state.map_data.rows) - 1)
	b = clampi(b, 0, int(_grid_state.map_data.cols) - 1)
	return Vector2i(a, b)

## 等距格 → 屏幕锚点（格中心的脚底位置）

func anchor_of(a: int, b: int) -> Vector2:
	return Vector2(_grid_state.tile_w * a + _grid_state.tile_hw * float(b & 1) + _grid_state.tile_hw, _grid_state.tile_hh * b + _grid_state.tile_hw)

## R9：取**最近**的可走格（原先取左上优先扫描到的第一个）。`layer=1` 时按水面层找。

func near_walkable(c: Vector2i, layer := 0) -> Vector2i:
	if not is_solid(c, layer):
		return c
	var rows := int(_grid_state.map_data.rows)
	var cols := int(_grid_state.map_data.cols)
	var best := c
	var bd := 1.0e12
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue            # 只看当前这一圈
				var p := Vector2i(clampi(c.x + dx, 0, rows - 1), clampi(c.y + dy, 0, cols - 1))
				if is_solid(p, layer):
					continue
				var d := float(dx * dx + dy * dy)
				if d < bd:
					bd = d
					best = p
		if bd < 1.0e12:
			return best
	return c

# ------------------------------------------------------------ 占格开关 ----

func is_solid(c: Vector2i, layer := 0) -> bool:
	var g := _grid(layer)
	return g.is_point_disabled(_id(c)) or int(_grid_state.occupancy.get(_id(c), 0)) > 0

## Candidate interaction cells use the same friendly-gate rule as A* planning.
## This query never changes the live gate state or permits terrain/building walls.

func is_solid_for_order(c: Vector2i, owner: int, layer := 0) -> bool:
	if not is_solid(c,layer): return false
	var id := _id(c)
	if layer != 0 or not _grid_state.gate_cells.has(id): return true
	if _land_terrain_blocked(id) or int(_grid_state.occupancy.get(id,0)) > 0 or _grid_state.blocked_cells.has(id): return true
	for gate in _grid_state.gate_cells[id]:
		if not bool(gate.alive) or float(gate.get("die_t",-1)) >= 0: continue
		if bool(gate.get("site",false)): return true
		if not bool(gate.get("gate_open",false)) and int(gate.owner) != owner: return true
	return false

## 该格是否可通航水面（用于"上船/下船"的目标校验与面板提示）。

func is_water(c: Vector2i) -> bool:
	return _grid_state.has_water and not _grid_state.water_astar.is_point_disabled(_id(c))

func _land_terrain_blocked(id: int) -> bool:
	if _grid_state.resource_cells.has(id):
		if bool(_grid_state.resource_cells[id]):return true
		# A few source trees overlap a shoreline water cell. Harvesting exposes
		# the original water, not a new land bridge.
		var water:Array=_grid_state.map_data.get("waterWalkable",[])
		return id<water.size() and int(water[id])!=0
	var walk: Array = _grid_state.map_data.get("terrainWalkable",_grid_state.map_data.get("walkable",[]))
	return int(walk[id]) == 0

func set_resources(objects: Array) -> void:
	var changed: Array = _grid_state.resource_cells.keys()
	_grid_state.resource_cells.clear()
	for object in objects:
		if int(object.get("phase",-1)) not in [0,1,2,3,4,5]: continue
		var cell := cell_of_px(float(object.ax),float(object.ay))
		if not _in_bounds(cell): continue
		var id := _id(cell)
		_grid_state.resource_cells[id] = bool(object.get("alive",false))
		changed.append(id)
	var cells: Array = []
	for id in changed:
		_grid_state.astar.set_point_disabled(int(id),_land_terrain_blocked(int(id)) or int(_grid_state.occupancy.get(id,0))>0 or _grid_state.blocked_cells.has(id))
		cells.append(_cell_of_id(int(id)))
	_mark_shape_dirty(cells,0)
	_refresh_gate_points()
	_grid_state.version+=1

func clear_resource(cell: Vector2i) -> void:
	if not _in_bounds(cell): return
	var id := _id(cell)
	if _grid_state.resource_cells.has(id) and not bool(_grid_state.resource_cells[id]): return
	_grid_state.resource_cells[id] = false
	_grid_state.astar.set_point_disabled(id,_land_terrain_blocked(id) or int(_grid_state.occupancy.get(id,0))>0 or _grid_state.blocked_cells.has(id))
	_mark_shape_dirty([cell],0)
	_refresh_gate_points()
	_grid_state.version+=1

## 封格（建筑落成占地、测试造不可达目标）

func block(c: Vector2i) -> void:
	_grid_state.blocked_cells[_id(c)] = true
	_grid_state.astar.set_point_disabled(_id(c), true)
	_mark_shape_dirty([c], 0)
	_grid_state.version += 1

func unblock(c: Vector2i) -> void:
	_grid_state.blocked_cells.erase(_id(c))
	var resource_blocked:=_land_terrain_blocked(_id(c)) if _grid_state.resource_cells.has(_id(c)) else false
	_grid_state.astar.set_point_disabled(_id(c), int(_grid_state.occupancy.get(_id(c), 0)) > 0 or resource_blocked)
	_refresh_gate_points()
	_mark_shape_dirty([c], 0)
	_grid_state.version += 1

# -------------------------------------------------------------- 寻路 ----
## ARCH-003：返回**空数组表示寻路失败**，绝不再兜底成直线。
## 旧实现在 `get_id_path` 为空时仍 `pts.append(target_px)`，于是"点水面"会退化成穿墙直走。
## R04：`unit_id` 决定整块占格档；0/缺省保持原单格行为，多格单位走按形状禁用的图。

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < int(_grid_state.map_data.rows) and c.y < int(_grid_state.map_data.cols)

## 形状感知的最近可放格（单格档沿用原 near_walkable，保持既有行为）。

func _mark_shape_dirty(cells: Array, layer: int) -> void:
	if _grid_state._shape_graphs.is_empty():
		return
	for key in _grid_state._shape_graphs:
		var parts: PackedStringArray = str(key).split(":")
		if parts.size() != 2: continue
		var key_layer := int(parts[0])
		var cls := int(parts[1])
		if layer >= 0 and key_layer != layer: continue
		var pending: Dictionary = _grid_state._shape_pending.get(key, {})
		for raw in cells:
			var c: Vector2i = raw
			for off in UnitFootprint.offsets(cls, 0):
				var a: Vector2i = c - off
				if (a.y & 1) == 0 and _in_bounds(a):
					pending[_id(a)] = a
			for off in UnitFootprint.offsets(cls, 1):
				var a2: Vector2i = c - off
				if (a2.y & 1) == 1 and _in_bounds(a2):
					pending[_id(a2)] = a2
		_grid_state._shape_pending[key] = pending

func footprint(anchor: Vector2, width: float, depth: float) -> Array[Vector2i]:
	# Generic geometry helper: a square in the diamond lattice, not in offset x/y.
	var result: Array[Vector2i] = []
	var origin := cell_of_px(anchor.x, anchor.y)
	var side := maxi(1, ceili(maxf(width / _grid_state.tile_w, depth / (_grid_state.tile_hh * 2))))
	var u0 := origin.x + ((origin.y + (origin.y & 1)) >> 1)
	var v0 := origin.y - u0
	for du in range(side):
		for dv in range(side):
			var u := u0 - du
			var b := u + v0 - dv
			var c := Vector2i(u - ((b + (b & 1)) >> 1), b)
			if c.x < 0 or c.y < 0 or c.x >= int(_grid_state.map_data.rows) or c.y >= int(_grid_state.map_data.cols):
				return []
			result.append(c)
	return result

func can_place(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	for c in cells:
		if is_solid(c):
			return false
	return true

## CONF-20 / R02: map load, player placement, preview and save rebuild share
## the original type's 1/4/9-cell square. Sprite dimensions never set collision.

func building_footprint(unit_id: int, anchor: Vector2, _width: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in UnitFootprint.shape(unit_id, cell_of_px(anchor.x, anchor.y)):
		if cell.x < 0 or cell.y < 0 or cell.x >= int(_grid_state.map_data.rows) or cell.y >= int(_grid_state.map_data.cols): return []
		result.append(cell)
	return result

## The hull is the exact outer boundary because CONF-20 footprints tile a square.

func footprint_outline(cells: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cells:
		var p := anchor_of(cell.x, cell.y)
		points.append(p + Vector2(0, -_grid_state.tile_hh))
		points.append(p + Vector2(_grid_state.tile_hw, 0))
		points.append(p + Vector2(0, _grid_state.tile_hh))
		points.append(p + Vector2(-_grid_state.tile_hw, 0))
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.resize(hull.size() - 1)
	return hull

func occupy(cells: Array, delta: int) -> void:
	var water: Array = _grid_state.map_data.get("waterWalkable", [])
	for c in cells:
		var id := _id(c)
		_grid_state.occupancy[id] = maxi(0, int(_grid_state.occupancy.get(id, 0)) + delta)
		var occupied: bool = int(_grid_state.occupancy[id]) > 0
		_grid_state.astar.set_point_disabled(id, _land_terrain_blocked(id) or occupied or _grid_state.blocked_cells.has(id))
		if _grid_state.has_water:
			_grid_state.water_astar.set_point_disabled(id, int(water[id]) == 0 or occupied)
	_mark_shape_dirty(cells, -1)
	_refresh_gate_points()
	_grid_state.version += 1

func register_gate(gate: Dictionary) -> void:
	if gate in _grid_state.gates:
		return
	_grid_state.gates.append(gate)
	gate["gate_open"] = false
	gate["occupied_cells"] = []
	var center := cell_of_px(float(gate.ax), float(gate.ay))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := center + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= int(_grid_state.map_data.rows) or c.y >= int(_grid_state.map_data.cols):
				continue
			var id := _id(c)
			if not _grid_state.gate_cells.has(id): _grid_state.gate_cells[id] = []
			_grid_state.gate_cells[id].append(gate)
	_refresh_gate_points()
	_grid_state.version += 1

func set_gate_open(gate: Dictionary, opened: bool) -> void:
	if bool(gate.get("gate_open", false)) == opened:
		return
	gate["gate_open"] = opened
	_refresh_gate_points()
	_grid_state.version += 1

func remove_gate(gate: Dictionary) -> void:
	if gate not in _grid_state.gates: return
	_grid_state.gates.erase(gate)
	for id in _grid_state.gate_cells:
		_grid_state.gate_cells[id].erase(gate)
	_refresh_gate_points()
	_grid_state.version += 1

func _refresh_gate_points() -> void:
	for id in _grid_state.gate_cells:
		var closed: bool = _land_terrain_blocked(int(id)) or int(_grid_state.occupancy.get(id, 0)) > 0 or _grid_state.blocked_cells.has(id)
		for gate in _grid_state.gate_cells[id]:
			if not bool(gate.alive) or float(gate.get("die_t", -1.0)) >= 0.0: continue
			var friendly_order: bool = _grid_state._planning_gates and _grid_state._route_owner >= 0 and int(gate.owner) == _grid_state._route_owner
			if bool(gate.get("site", false)) or (not bool(gate.get("gate_open", false)) and not friendly_order):
				closed = true
		_grid_state.astar.set_point_disabled(int(id), closed)
		# 城门开闭会改变整块身体的合法性：把受影响锚点标脏，下次查询前刷新。
		if not _grid_state._shape_graphs.is_empty():
			_mark_shape_dirty([_cell_of_id(int(id))], 0)

func rebuild_buildings(units: Array) -> void:
	var resources := _grid_state.resource_cells.duplicate()
	setup(_grid_state.map_data)
	_grid_state.resource_cells = resources
	for id in _grid_state.resource_cells:
		_grid_state.astar.set_point_disabled(int(id),_land_terrain_blocked(int(id)))
	for u in units:
		if bool(u.is_building) and bool(u.alive):
			# The terrain supplies the arch passage; the live gate controls its closure.
			if int(u.unit) == 16 or int(u.unit) == 17:
				register_gate(u)
				continue
			# CONF-20 / R02: the same type-based square as new construction.
			var cells := building_footprint(int(u.unit), Vector2(u.ax, u.ay), float(u.w))
			u["occupied_cells"] = cells
			occupy(cells, 1)
