extends RefCounted
## path queries.
const GridState = preload("res://simulation/navigation/navigation_state.gd")
var _grid_state: GridState
var ports = preload("res://simulation/ports/path_queries_dependencies.gd").new()
const UnitFootprint = preload("res://simulation/systems/unit_footprint.gd")

func _init(data: GridState) -> void:
	_grid_state = data

func find_path(from_px: Vector2, to_px: Vector2, exact: bool, layer := 0, owner := -1, unit_id := -1) -> Array:
	var cls := UnitFootprint.class_of(int(unit_id)) if int(unit_id) >= 0 else 0
	# Friendly orders may plan through their closed automatic gates. Only the
	# synchronous route query uses this graph; movement always sees the real state.
	_grid_state._route_owner = owner
	_grid_state._planning_gates = true
	ports._refresh_gate_points()
	_grid_for(layer, cls)               # 确保形状图存在（首次按当前阻挡生成）
	_shape_apply_dirty(layer, cls)
	var result := _find_path(from_px, to_px, exact, layer, cls)
	result = _smooth_path(from_px,result,layer,cls)
	_grid_state._route_owner = -1
	_grid_state._planning_gates = false
	ports._refresh_gate_points()
	return result

## 临时避让其他单位占格：只在本查询期间禁用，查询后恢复原状态。
## 用于“不叠格”后的绕行，避免把前排单位当成永久墙或直接堵死。

func find_path_avoiding(from_px: Vector2, to_px: Vector2, exact: bool, avoid_cells: Array, layer := 0, owner := -1, unit_id := -1) -> Array:
	var cls := UnitFootprint.class_of(int(unit_id)) if int(unit_id) >= 0 else 0
	if avoid_cells.is_empty():
		return find_path(from_px, to_px, exact, layer, owner, unit_id)
	_grid_state._route_owner = owner
	_grid_state._planning_gates = true
	ports._refresh_gate_points()
	var g := _grid_for(layer, cls)
	_shape_apply_dirty(layer, cls)
	var prev := {}
	for raw in avoid_cells:
		var c: Vector2i = raw
		if cls <= 0:
			var id := ports._id(c)
			if prev.has(id): continue
			prev[id] = g.is_point_disabled(id)
			g.set_point_disabled(id, true)
			continue
		# 形状图禁用的是**锚点**：只要身体会盖住避让格，该锚点就不可用。
		for off in UnitFootprint.offsets(cls, 0):
			var a: Vector2i = c - off
			if (a.y & 1) != 0 or not ports._in_bounds(a): continue
			var aid := ports._id(a)
			if prev.has(aid): continue
			prev[aid] = g.is_point_disabled(aid)
			g.set_point_disabled(aid, true)
		for off in UnitFootprint.offsets(cls, 1):
			var a2: Vector2i = c - off
			if (a2.y & 1) == 0 or not ports._in_bounds(a2): continue
			var aid2 := ports._id(a2)
			if prev.has(aid2): continue
			prev[aid2] = g.is_point_disabled(aid2)
			g.set_point_disabled(aid2, true)
	var result := _find_path(from_px, to_px, exact, layer, cls)
	result = _smooth_path(from_px,result,layer,cls)
	for id in prev:
		g.set_point_disabled(int(id), bool(prev[id]))
	_grid_state._route_owner = -1
	_grid_state._planning_gates = false
	ports._refresh_gate_points()
	return result

## Remove the offset grid's staircase only where the same planning graph permits
## a straight segment. Temporary crop/unit avoidance and whole-body clearance
## therefore apply to shortcuts too. Gate waypoints remain for automatic opening.

func _smooth_path(origin: Vector2, points: Array, layer: int, cls: int) -> Array:
	var result := []
	var from := origin
	var first := 0
	while first<points.size():
		if from.distance_squared_to(points[first])<0.0001:
			first+=1;continue
		var last := mini(points.size()-1,first+15)
		for i in range(first,last+1):
			if _grid_state.gate_cells.has(ports._id(ports.cell_of_px(points[i].x,points[i].y))):last=i;break
		var chosen := first
		for i in range(last,first,-1):
			if _shortcut_clear(from,points[i],layer,cls):chosen=i;break
		from=points[chosen];result.append(from);first=chosen+1
	# A nonempty same-cell route must still signal successful arrival.
	return result if not result.is_empty() or points.is_empty() else [points.back()]

func _shortcut_clear(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	var graph:=_grid_for(layer,cls)
	var start:=ports.cell_of_px(a.x,a.y)
	var count:=maxi(1,ceili(a.distance_to(b)/(_grid_state.tile_hh*0.25)))
	for i in range(1,count+1):
		var p:=a.lerp(b,float(i)/count)
		if p.x<0 or p.y<0 or p.x>=float(_grid_state.map_data.terrainW) or p.y>=float(_grid_state.map_data.terrainH):return false
		var cell:=ports.cell_of_px(p.x,p.y)
		if cell!=start and graph.is_point_disabled(ports._id(cell)):return false
	return true

func _find_path(from_px: Vector2, to_px: Vector2, exact: bool, layer: int, cls: int) -> Array:
	var g := _grid_for(layer, cls)
	# B6：起点也要吸附，否则单位站在建筑/水域格时 get_id_path 返回空 → 直穿
	# 2026-10-16 加固：单位可能贴着/挤进不可走格的角落（停下时像素落在斜角格的另一边），
	# 此时 from 的吸附点与当前位置之间的**视线**会被挡住。这里改为：
	# 在起点周围扩充环里找第一个「可走且从其锚点看得见单位当前位置」的格当出发格；
	# 找不到才返回空（维持 ARCH-003：绝不编一条穿墙直线）。
	var from0 := ports.cell_of_px(from_px.x, from_px.y)
	var from := from0
	var origin := ports.anchor_of(from.x, from.y)
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
					var an := ports.anchor_of(c.x, c.y)
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
	var to := _near_fitting(ports.cell_of_px(to_px.x, to_px.y), layer, cls)
	if not _anchor_fits(to, layer, cls):
		return []
	if from == to:
		return [ports.anchor_of(to.x, to.y)] if exact else []
	var ids = g.get_id_path(ports._id(from), ports._id(to))
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
				else (_anchor_fits(ports.cell_of_px(to_px.x, to_px.y), layer, cls) and _segment_clear_for(pts.back(), to_px, layer, cls))
		if exact_ok:
			pts.append(to_px)
	return pts

## 该锚点是否放得下整块身体（地形/建筑占地/封格/城门都折算进 is_solid）。

func _anchor_fits(anchor: Vector2i, layer: int, cls: int) -> bool:
	if cls <= 0:
		return not ports.is_solid(anchor, layer)
	for raw in UnitFootprint.offsets(cls, anchor.y):
		var c: Vector2i = anchor + raw
		if not ports._in_bounds(c) or ports.is_solid(c, layer):
			return false
	return true

func _near_fitting(cell: Vector2i, layer: int, cls: int) -> Vector2i:
	if cls <= 0:
		return ports.near_walkable(cell, layer)
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
	var allow := {}
	if cls > 0:
		var start_anchor := ports.cell_of_px(a.x, a.y)
		for raw in UnitFootprint.offsets(cls, start_anchor.y):
			allow[start_anchor + raw] = true
	if b.x < 0 or b.y < 0 or b.x >= float(_grid_state.map_data.terrainW) or b.y >= float(_grid_state.map_data.terrainH):
		return false
	var count := maxi(1, int(ceil(a.distance_to(b) / (_grid_state.tile_hh * 0.5))))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		var anchor := ports.cell_of_px(p.x, p.y)
		for raw in UnitFootprint.offsets(cls, anchor.y):
			var c: Vector2i = anchor + raw
			if allow.has(c):
				continue
			if not ports._in_bounds(c) or ports.is_solid(c, layer):
				return false
	return true

# --------------------------------------------------------- 形状图缓存 ----

func _grid_for(layer: int, cls: int) -> AStar2D:
	if cls <= 0:
		return ports._grid(layer)
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
			g.add_point(ports._id(c), ports.anchor_of(a, b))
	for a in range(rows):
		for b in range(cols):
			var c2 := Vector2i(a, b)
			for neighbor in ports.neighbors(c2):
				if not g.are_points_connected(ports._id(c2), ports._id(neighbor)):
					g.connect_points(ports._id(c2), ports._id(neighbor))
	for a in range(rows):
		for b in range(cols):
			var anchor := Vector2i(a, b)
			g.set_point_disabled(ports._id(anchor), not _anchor_fits(anchor, layer, cls))
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

func segment_clear(a: Vector2, b: Vector2, layer := 0) -> bool:
	if b.x < 0 or b.y < 0 or b.x >= float(_grid_state.map_data.terrainW) or b.y >= float(_grid_state.map_data.terrainH):
		return false
	var count := maxi(1, int(ceil(a.distance_to(b) / (_grid_state.tile_hh * 0.25))))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		if ports.is_solid(ports.cell_of_px(p.x, p.y), layer):
			return false
	return true

## REQ-003：**移动提交前**的当前段校验。与 segment_clear 的唯一差别：
## 跳过**起点所在的格**。单位可能贴着建筑/墙角停下，像素恰好落进实心格
## （见 find_path 里 B6 注释），而 _resolve_navigation_overlaps 只在 _ready 跑一次 ——
## 这种单位已经站在那里，必须允许它走出来；这里要拦的是「走进**新**出现的实心格」，
## 不是「自己脚下必须干净」，否则它会被自己的起点判死、原地卡死（违反 R-03 验收）。
## A* 内部段是相邻可走格锚点的连线，静态世界里不会穿过第三方实心格；
## 会让当前段变实的只有动态占地（建筑落成/地形封格）——正是本校验的目标场景。

func segment_clear_from(a: Vector2, b: Vector2, layer := 0) -> bool:
	if b.x < 0 or b.y < 0 or b.x >= float(_grid_state.map_data.terrainW) or b.y >= float(_grid_state.map_data.terrainH):
		return false
	var from_cell := ports.cell_of_px(a.x, a.y)
	var count := maxi(1, int(ceil(a.distance_to(b) / (_grid_state.tile_hh * 0.25))))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		var c := ports.cell_of_px(p.x, p.y)
		if c == from_cell:
			continue
		if ports.is_solid(c, layer):
			return false
	return true
