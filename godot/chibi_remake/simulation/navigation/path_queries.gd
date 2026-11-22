extends RefCounted
## path queries.
const GridState = preload("res://simulation/navigation/navigation_state.gd")
var _grid_state: GridState
const ProfileClock = preload("res://simulation/core/profile_clock.gd")
var profile_enabled := false
var _dep_grid: RefCounted
const GridRay = preload("res://simulation/navigation/grid_ray.gd")
var _gate_shape_version := -1
var _gate_shape_cache: Dictionary={}
var metrics := {"calls":0,"microseconds":0,"smoothMicroseconds":0,"searchMicroseconds":0,"rayCells":0,"avoidWrites":0,"avoidScopes":0}
const UnitFootprint = preload("res://simulation/navigation/unit_footprint.gd")

func _init(data: GridState) -> void:
	_grid_state = data

func find_path(from_px: Vector2, to_px: Vector2, exact: bool, layer := 0, owner := -1, unit_id := -1) -> Array:
	var begin:=ProfileClock.now(profile_enabled)
	var result:=_query_path(from_px,to_px,exact,layer,owner,unit_id)
	metrics.calls+=1;metrics.microseconds+=ProfileClock.now(profile_enabled)-begin
	return result

func find_path_avoiding(from_px: Vector2, to_px: Vector2, exact: bool, avoid_cells: Array, layer := 0, owner := -1, unit_id := -1) -> Array:
	var begin:=ProfileClock.now(profile_enabled)
	var result:=_query_avoiding(from_px,to_px,exact,avoid_cells,layer,owner,unit_id)
	metrics.calls+=1;metrics.microseconds+=ProfileClock.now(profile_enabled)-begin
	return result

func _query_path(from_px: Vector2, to_px: Vector2, exact: bool, layer := 0, owner := -1, unit_id := -1) -> Array:
	var cls := UnitFootprint.class_of(int(unit_id)) if int(unit_id) >= 0 else 0
	# Friendly orders may plan through their closed automatic gates. Only the
	# synchronous route query uses this graph; movement always sees the real state.
	var g:=_grid_for(layer,cls)
	_shape_apply_dirty(layer,cls)
	var route_gates: Array = _dep_grid.open_route_gates(owner,layer)
	var gate_shape:=_route_shape_gates(route_gates,layer,cls,owner)
	var result := _find_path(from_px, to_px, exact, layer, cls)
	result = _smooth_path(from_px,result,layer,cls)
	for id in gate_shape:g.set_point_disabled(int(id),bool(gate_shape[id]))
	_dep_grid.close_route_gates(route_gates)
	return result

## 临时避让其他单位占格：只在本查询期间禁用，查询后恢复原状态。
## 用于“不叠格”后的绕行，避免把前排单位当成永久墙或直接堵死。

func _query_avoiding(from_px: Vector2, to_px: Vector2, exact: bool, avoid_cells: Array, layer := 0, owner := -1, unit_id := -1) -> Array:
	var cls := UnitFootprint.class_of(int(unit_id)) if int(unit_id) >= 0 else 0
	if avoid_cells.is_empty():
		return _query_path(from_px, to_px, exact, layer, owner, unit_id)
	var g := _grid_for(layer, cls)
	_shape_apply_dirty(layer, cls)
	var route_gates: Array = _dep_grid.open_route_gates(owner,layer)
	var gate_shape:=_route_shape_gates(route_gates,layer,cls,owner)
	var prev := _avoid_overlay(g, avoid_cells, cls)
	var result := _find_path(from_px, to_px, exact, layer, cls)
	result = _smooth_path(from_px,result,layer,cls)
	for id in prev:
		g.set_point_disabled(int(id), bool(prev[id]))
	for id in gate_shape:g.set_point_disabled(int(id),bool(gate_shape[id]))
	_dep_grid.close_route_gates(route_gates)
	return result

func _avoid_overlay(g: AStar2D, avoid_cells: Array, cls: int, except_cell := Vector2i(-1,-1)) -> Dictionary:
	var prev := {}
	metrics.avoidScopes += 1
	var rows:=int(_grid_state.map_data.rows);var cols:=int(_grid_state.map_data.cols)
	var even:=UnitFootprint.offsets(cls,0);var odd:=UnitFootprint.offsets(cls,1)
	for raw in avoid_cells:
		var c: Vector2i = raw
		if c == except_cell: continue
		if cls <= 0:
			var id := c.x*cols+c.y
			if prev.has(id): continue
			if g.is_point_disabled(id): continue
			prev[id] = false
			g.set_point_disabled(id, true); metrics.avoidWrites += 1
			continue
		# 形状图禁用的是**锚点**：只要身体会盖住避让格，该锚点就不可用。
		for off in even:
			var a: Vector2i = c - off
			if (a.y & 1) != 0 or a.x<0 or a.y<0 or a.x>=rows or a.y>=cols: continue
			var aid := a.x*cols+a.y
			if prev.has(aid): continue
			if g.is_point_disabled(aid): continue
			prev[aid] = false
			g.set_point_disabled(aid, true); metrics.avoidWrites += 1
		for off in odd:
			var a2: Vector2i = c - off
			if (a2.y & 1) == 0 or a2.x<0 or a2.y<0 or a2.x>=rows or a2.y>=cols: continue
			var aid2 := a2.x*cols+a2.y
			if prev.has(aid2): continue
			if g.is_point_disabled(aid2): continue
			prev[aid2] = false
			g.set_point_disabled(aid2, true); metrics.avoidWrites += 1
	return prev

func first_path_avoiding(origin: Vector2, destinations: Array, avoid_cells: Array, except_cell: Vector2i, layer: int, owner: int, unit_id: int, accepts: Callable) -> Dictionary:
	if destinations.is_empty(): return {}
	var begin := ProfileClock.now(profile_enabled)
	var cls := UnitFootprint.class_of(unit_id) if unit_id >= 0 else 0
	var graph := _grid_for(layer, cls)
	_shape_apply_dirty(layer, cls)
	var gates: Array = _dep_grid.open_route_gates(owner, layer)
	var gate_shape := _route_shape_gates(gates, layer, cls, owner)
	var previous := _avoid_overlay(graph, avoid_cells, cls, except_cell)
	var result := {}
	for index in range(destinations.size()):
		var path := _smooth_path(origin, _find_path(origin, destinations[index], true, layer, cls), layer, cls)
		metrics.calls += 1
		if not path.is_empty() and _cell(path.back()) == _cell(destinations[index]) and accepts.call(path):
			result = {"index":index,"path":path}
			break
	for id in previous: graph.set_point_disabled(int(id), bool(previous[id]))
	for id in gate_shape: graph.set_point_disabled(int(id), bool(gate_shape[id]))
	_dep_grid.close_route_gates(gates)
	metrics.microseconds += ProfileClock.now(profile_enabled) - begin
	return result

## Remove the offset grid's staircase only where the same planning graph permits
## a straight segment. Temporary crop/unit avoidance and whole-body clearance
## therefore apply to shortcuts too. Gate waypoints remain for automatic opening.

func _smooth_path(origin: Vector2, points: Array, layer: int, cls: int) -> Array:
	var begin:=ProfileClock.now(profile_enabled)
	var result:=_smooth_core(origin,points,layer,cls)
	metrics.smoothMicroseconds+=ProfileClock.now(profile_enabled)-begin
	return result

func _smooth_core(origin: Vector2, points: Array, layer: int, cls: int) -> Array:
	var result := []
	var from := origin
	var first := 0
	while first<points.size():
		if from.distance_squared_to(points[first])<0.0001:
			first+=1;continue
		var last := mini(points.size()-1,first+15)
		for i in range(first,last+1):
			var cell:=_cell(points[i])
			if _grid_state.gate_cells.has(cell.x*int(_grid_state.map_data.cols)+cell.y):last=i;break
		var chosen := first
		for i in range(last,first,-1):
			if _shortcut_clear(from,points[i],layer,cls):chosen=i;break
		from=points[chosen];result.append(from);first=chosen+1
	# A nonempty same-cell route must still signal successful arrival.
	return result if not result.is_empty() or points.is_empty() else [points.back()]

func _shortcut_clear(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	if not _inside(a) or not _inside(b):return false
	var graph:=_grid_for(layer,cls)
	var start:=_cell(a);var cols:=int(_grid_state.map_data.cols)
	var start_id:=start.x*cols+start.y
	for id in _ray(a,b):
		if id!=start_id and graph.is_point_disabled(id):return false
	return true

func _inside(point: Vector2) -> bool:
	return point.x>=0 and point.y>=0 and point.x<float(_grid_state.map_data.terrainW) and point.y<float(_grid_state.map_data.terrainH)

func _cell(point: Vector2) -> Vector2i:
	var row:=roundi((point.y-_grid_state.tile_hw)/_grid_state.tile_hh)
	return Vector2i(clampi(roundi((point.x-_grid_state.tile_hw-_grid_state.tile_hw*(row&1))/_grid_state.tile_w),0,int(_grid_state.map_data.rows)-1),clampi(row,0,int(_grid_state.map_data.cols)-1))

func _ray(a: Vector2,b: Vector2) -> PackedInt64Array:
	var cells:=GridRay.cells(a,b,_grid_state.tile_w,int(_grid_state.map_data.rows),int(_grid_state.map_data.cols))
	metrics.rayCells+=cells.size()
	return cells

func _solid_id(id: int, layer: int) -> bool:
	var graph: AStar2D=_grid_state.water_astar if layer==1 and _grid_state.has_water else _grid_state.astar
	return graph.is_point_disabled(id) or int(_grid_state.occupancy.get(id,0))>0

func contact_clear(a: Vector2,b: Vector2,ignore: Dictionary,layer: int) -> bool:
	var cols:=int(_grid_state.map_data.cols)
	for id in _ray(a,b):
		if not ignore.has(Vector2i(id/cols,id%cols)) and _solid_id(id,layer):return false
	return true

func _find_path(from_px: Vector2, to_px: Vector2, exact: bool, layer: int, cls: int) -> Array:
	var begin:=ProfileClock.now(profile_enabled)
	var result:=_find_path_core(from_px,to_px,exact,layer,cls)
	metrics.searchMicroseconds+=ProfileClock.now(profile_enabled)-begin
	return result

func _find_path_core(from_px: Vector2, to_px: Vector2, exact: bool, layer: int, cls: int) -> Array:
	var g := _grid_for(layer, cls)
	# B6：起点也要吸附，否则单位站在建筑/水域格时 get_id_path 返回空 → 直穿
	# 2026-10-16 加固：单位可能贴着/挤进不可走格的角落（停下时像素落在斜角格的另一边），
	# 此时 from 的吸附点与当前位置之间的**视线**会被挡住。这里改为：
	# 在起点周围扩充环里找第一个「可走且从其锚点看得见单位当前位置」的格当出发格；
	# 找不到才返回空（维持 ARCH-003：绝不编一条穿墙直线）。
	var from0: Vector2i = _dep_grid.cell_of_px(from_px.x, from_px.y)
	var from := from0
	var origin: Vector2 = _dep_grid.anchor_of(from.x, from.y)
	var start_ok := _anchor_fits(from, layer, cls) \
			and (from_px.distance_to(origin) <= 0.01 or _escape_clear_for(from_px, origin, layer, cls))
	if not start_ok:
		var found := false
		for r in range(1, 6):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var c := Vector2i(clampi(from0.x + dx, 0, int(_grid_state.map_data.rows) - 1),
						clampi(from0.y + dy, 0, int(_grid_state.map_data.cols) - 1))
					if not _anchor_fits(c, layer, cls):
						continue
					var an: Vector2 = _dep_grid.anchor_of(c.x, c.y)
					if _escape_clear_for(from_px, an, layer, cls):
						from = c
						origin = an
						found = true
						break
					if found:
						break
				if found:
					break
			if found:
				break
		if not found:
			return []
	var to := _near_fitting(_dep_grid.cell_of_px(to_px.x, to_px.y), layer, cls)
	if not _anchor_fits(to, layer, cls):
		return []
	if from == to:
		return [_dep_grid.anchor_of(to.x, to.y)] if exact else []
	# Open-ground orders can use the exact same collision graph directly. Keep
	# gate waypoints on A* routes because automatic opening observes those cells.
	var destination: Vector2=_dep_grid.anchor_of(to.x,to.y)
	if exact and _anchor_fits(_cell(to_px),layer,cls):destination=to_px
	if start_ok and _direct_route_clear(from_px,destination,g):return [destination]
	var ids = g.get_id_path(_dep_grid._id(from), _dep_grid._id(to))
	if ids.size() < 2:
		return []                      # 不可达：交给调用方反馈，不要编一条路出来
	var pts := []
	if from_px.distance_to(origin) > 0.01:
		if not _escape_clear_for(from_px, origin, layer, cls):
			return []
		pts.append(origin)
	var previous := origin
	for i in range(1, ids.size()):
		var point: Vector2 = g.get_point_position(ids[i])
		# 形状图只保证锚点合法；相邻锚点之间的扫掠在拐角仍可能蹭到实心格。
		if cls > 0 and not _segment_clear_for(previous, point, layer, cls):
			return []
		pts.append(point)
		previous = point
	if exact:
		var exact_ok := segment_clear(pts.back(), to_px, layer) if cls <= 0 \
				else (_anchor_fits(_dep_grid.cell_of_px(to_px.x, to_px.y), layer, cls) and _segment_clear_for(pts.back(), to_px, layer, cls))
		if exact_ok:
			pts.append(to_px)
	return pts

## 该锚点是否放得下整块身体（地形/建筑占地/封格/城门都折算进 is_solid）。

func _anchor_fits(anchor: Vector2i, layer: int, cls: int) -> bool:
	var cols:=int(_grid_state.map_data.cols);var rows:=int(_grid_state.map_data.rows)
	if anchor.x<0 or anchor.y<0 or anchor.x>=rows or anchor.y>=cols:return false
	if cls==0:return not _solid_id(anchor.x*cols+anchor.y,layer)
	for offset in UnitFootprint.offsets(cls,anchor.y):
		var cell: Vector2i=anchor+offset
		if cell.x<0 or cell.y<0 or cell.x>=rows or cell.y>=cols or _solid_id(cell.x*cols+cell.y,layer):return false
	return true

func _near_fitting(cell: Vector2i, layer: int, cls: int) -> Vector2i:
	if cls <= 0:
		return _dep_grid.near_walkable(cell, layer)
	if _anchor_fits(cell, layer, cls):
		return cell
	# 与 near_walkable 相同的 5 圈上限：自检用 ±6 格封闭块验证“不可达必须返回空”，
	# 搜索半径不能超过封块，否则会把墙上另一侧的格子当成替代终点。
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(clampi(cell.x + dx, 0, int(_grid_state.map_data.rows) - 1),
					clampi(cell.y + dy, 0, int(_grid_state.map_data.cols) - 1))
				if _anchor_fits(c, layer, cls):
					return c
	return cell

## 单格用原 segment_clear；多格按整块身体采样（含扫掠中间位置）。

func _segment_clear_for(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	if cls <= 0:
		return segment_clear(a, b, layer)
	return body_segment_clear_from(a, b, layer, cls)

## 起点逃逸/吸附专用：单格跳过自己脚下的实心格（REQ-003），多格按整块身体。

func _escape_clear_for(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	if cls <= 0:
		return segment_clear_from(a, b, layer)
	return body_segment_clear_from(a, b, layer, cls)

## R04：身体从 a 扫到 b 的整块占格校验。`allow_current` 为真时忽略**当前身体**
## 已压住的实心格，保证被建筑/旧档包住的单位仍能挤出来；其余实心格一律禁止穿越。

func body_segment_clear_from(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	if not _inside(b):return false
	var allow: Dictionary={};var start:=_cell(a);var cols:=int(_grid_state.map_data.cols)
	for offset in UnitFootprint.offsets(cls,start.y):allow[start+offset]=true
	for id in _ray(a,b):
		var anchor:=Vector2i(id/cols,id%cols)
		for offset in UnitFootprint.offsets(cls,anchor.y):
			var cell: Vector2i=anchor+offset
			if allow.has(cell):continue
			if cell.x<0 or cell.y<0 or cell.x>=int(_grid_state.map_data.rows) or cell.y>=cols or _solid_id(cell.x*cols+cell.y,layer):return false
	return true

# --------------------------------------------------------- 形状图缓存 ----

func _grid_for(layer: int, cls: int) -> AStar2D:
	if cls <= 0:
		return _grid_state.water_astar if layer==1 and _grid_state.has_water else _grid_state.astar
	return _shape_graph(layer, cls)

func _shape_key(layer: int, cls: int) -> String:
	return "%d:%d" % [layer, cls]

func _shape_graph(layer: int, cls: int) -> AStar2D:
	var key := _shape_key(layer, cls)
	if _grid_state._shape_graphs.has(key):
		return _grid_state._shape_graphs[key]
	var g := AStar2D.new()
	var rows := int(_grid_state.map_data.rows)
	var cols := int(_grid_state.map_data.cols)
	for a in range(rows):
		for b in range(cols):
			var c := Vector2i(a, b)
			var id: int = _dep_grid._id(c)
			g.add_point(id, _grid_state.astar.get_point_position(id))
	# Reuse the exact connection order created by Grid.setup. Geometry is shared;
	# only each footprint's disabled flags differ. This preserves A* tie breaking
	# without repeating millions of weak-port calls on every restored world.
	var edges: PackedInt64Array = _grid_state.topology_edges
	for edge in range(0,edges.size(),2):
		g.connect_points(edges[edge],edges[edge+1])
	for a in range(rows):
		for b in range(cols):
			var anchor := Vector2i(a, b)
			g.set_point_disabled(_dep_grid._id(anchor), not _anchor_fits(anchor, layer, cls))
	_grid_state._shape_graphs[key] = g
	_grid_state._shape_pending[key] = {}
	return g

## 占格/封格/城门变化后，只把「身体会盖住变化格」的锚点标脏；
## 下一次该档查询前增量重算，避免整图重建或每 tick 全扫。

func _shape_apply_dirty(layer: int, cls: int) -> void:
	if cls <= 0: return
	var key := _shape_key(layer, cls)
	if not _grid_state._shape_graphs.has(key): return
	var pending: Dictionary = _grid_state._shape_pending.get(key, {})
	if pending.is_empty(): return
	var g: AStar2D = _grid_state._shape_graphs[key]
	for id in pending:
		var anchor: Vector2i = pending[id]
		g.set_point_disabled(int(id), not _anchor_fits(anchor, layer, cls))
	pending.clear()

func segment_clear(a: Vector2,b: Vector2,layer:=0) -> bool:
	if not _inside(b):return false
	for id in _ray(a,b):
		if _solid_id(id,layer):return false
	return true

func segment_clear_from(a: Vector2,b: Vector2,layer:=0) -> bool:
	if not _inside(b):return false
	var start:=_cell(a);var start_id:=start.x*int(_grid_state.map_data.cols)+start.y
	for id in _ray(a,b):
		if id!=start_id and _solid_id(id,layer):return false
	return true

## Planning gates are an overlay of this query's graph, never a topology edit.
## Restore the exact previous flags so a single-cell route does not dirty every
## cached footprint graph twice, and other owners cannot reuse an open gate.
func _route_shape_gates(ids: Array, layer: int, cls: int, owner: int) -> Dictionary:
	var previous: Dictionary={}
	if cls==0 or ids.is_empty():return previous
	if _gate_shape_version!=_grid_state.version:
		_gate_shape_cache.clear();_gate_shape_version=_grid_state.version
	var cache_key:=Vector3i(layer,cls,owner)
	var graph:=_grid_for(layer,cls)
	if not _gate_shape_cache.has(cache_key):
		var flags: Dictionary={};var cols:=int(_grid_state.map_data.cols);var rows:=int(_grid_state.map_data.rows)
		for id in ids:
			var cell:=Vector2i(int(id)/cols,int(id)%cols)
			for parity in [0,1]:
				for offset in UnitFootprint.offsets(cls,parity):
					var anchor: Vector2i=cell-offset
					if (anchor.y&1)!=parity or anchor.x<0 or anchor.y<0 or anchor.x>=rows or anchor.y>=cols:continue
					var key:=anchor.x*cols+anchor.y
					if not flags.has(key):flags[key]=not _anchor_fits(anchor,layer,cls)
		_gate_shape_cache[cache_key]=flags
	var overlay: Dictionary=_gate_shape_cache[cache_key]
	for id in overlay:
		var disabled:=graph.is_point_disabled(int(id))
		if disabled==bool(overlay[id]):continue
		previous[id]=disabled;graph.set_point_disabled(int(id),bool(overlay[id]))
	return previous

func _direct_route_clear(a: Vector2,b: Vector2,graph: AStar2D) -> bool:
	if not _inside(a) or not _inside(b):return false
	var start:=_cell(a);var start_id:=start.x*int(_grid_state.map_data.cols)+start.y
	for id in _ray(a,b):
		if _grid_state.gate_cells.has(id) or (id!=start_id and graph.is_point_disabled(id)):return false
	return true

func bind_dependencies(navigation: Object) -> void:
	_dep_grid = navigation.grid
