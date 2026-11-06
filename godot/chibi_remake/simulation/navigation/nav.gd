extends RefCounted
## Stable navigation API backed by grid and path-query components.
var state = preload("res://simulation/navigation/navigation_state.gd").new()
var grid = preload("res://simulation/navigation/navigation_grid.gd").new(state)
var paths = preload("res://simulation/navigation/path_queries.gd").new(state)
var _fields: Dictionary = {}
var _api_missing: Array = []

func _init() -> void:
	for field in state.PROXY_FIELDS: _fields[field] = true
	var services := {"grid": grid, "paths": paths}
	var report := preload("res://composition_contract.gd").wire(services, "nav")
	_api_missing = report.missing

func _get(key: StringName):
	if _fields.has(key): return state.get(key)
	push_error("Unknown simulation/navigation/nav.gd state property: " + str(key))
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): state.set(key, value); return true
	push_error("Unknown simulation/navigation/nav.gd state property: " + str(key))
	return false

func setup(md: Dictionary) -> void:
	grid.setup(md)
func _id(c: Vector2i) -> int:
	return grid._id(c)
func _cell_of_id(id: int) -> Vector2i:
	return grid._cell_of_id(id)
func _grid(layer: int) -> AStar2D:
	return grid._grid(layer)
func neighbors(c: Vector2i) -> Array[Vector2i]:
	return grid.neighbors(c)
func cell_of_px(px: float, py: float) -> Vector2i:
	return grid.cell_of_px(px, py)
func anchor_of(a: int, b: int) -> Vector2:
	return grid.anchor_of(a, b)
func near_walkable(c: Vector2i, layer := 0) -> Vector2i:
	return grid.near_walkable(c, layer)
func is_solid(c: Vector2i, layer := 0) -> bool:
	return grid.is_solid(c, layer)
func is_solid_for_order(c: Vector2i, owner: int, layer := 0) -> bool:
	return grid.is_solid_for_order(c, owner, layer)
func is_water(c: Vector2i) -> bool:
	return grid.is_water(c)
func _land_terrain_blocked(id: int) -> bool:
	return grid._land_terrain_blocked(id)
func set_resources(objects: Array) -> void:
	grid.set_resources(objects)
func clear_resource(cell: Vector2i) -> void:
	grid.clear_resource(cell)
func block(c: Vector2i) -> void:
	grid.block(c)
func unblock(c: Vector2i) -> void:
	grid.unblock(c)
func find_path(from_px: Vector2, to_px: Vector2, exact: bool, layer := 0, owner := -1, unit_id := -1) -> Array:
	return paths.find_path(from_px, to_px, exact, layer, owner, unit_id)
func find_path_avoiding(from_px: Vector2, to_px: Vector2, exact: bool, avoid_cells: Array, layer := 0, owner := -1, unit_id := -1) -> Array:
	return paths.find_path_avoiding(from_px, to_px, exact, avoid_cells, layer, owner, unit_id)
func _smooth_path(origin: Vector2, points: Array, layer: int, cls: int) -> Array:
	return paths._smooth_path(origin, points, layer, cls)
func _shortcut_clear(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	return paths._shortcut_clear(a, b, layer, cls)
func _anchor_fits(anchor: Vector2i, layer: int, cls: int) -> bool:
	return paths._anchor_fits(anchor, layer, cls)
func _in_bounds(c: Vector2i) -> bool:
	return grid._in_bounds(c)
func _near_fitting(cell: Vector2i, layer: int, cls: int) -> Vector2i:
	return paths._near_fitting(cell, layer, cls)
func _segment_clear_for(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	return paths._segment_clear_for(a, b, layer, cls)
func _escape_clear_for(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	return paths._escape_clear_for(a, b, layer, cls)
func body_segment_clear_from(a: Vector2, b: Vector2, layer: int, cls: int) -> bool:
	return paths.body_segment_clear_from(a, b, layer, cls)
func _grid_for(layer: int, cls: int) -> AStar2D:
	return paths._grid_for(layer, cls)
func _shape_key(layer: int, cls: int) -> String:
	return paths._shape_key(layer, cls)
func _shape_graph(layer: int, cls: int) -> AStar2D:
	return paths._shape_graph(layer, cls)
func _mark_shape_dirty(cells: Array, layer: int) -> void:
	grid._mark_shape_dirty(cells, layer)
func _shape_apply_dirty(layer: int, cls: int) -> void:
	paths._shape_apply_dirty(layer, cls)
func segment_clear(a: Vector2, b: Vector2, layer := 0) -> bool:
	return paths.segment_clear(a, b, layer)
func segment_clear_from(a: Vector2, b: Vector2, layer := 0) -> bool:
	return paths.segment_clear_from(a, b, layer)
func footprint(anchor: Vector2, width: float, depth: float) -> Array[Vector2i]:
	return grid.footprint(anchor, width, depth)
func can_place(cells: Array[Vector2i]) -> bool:
	return grid.can_place(cells)
func building_footprint(unit_id: int, anchor: Vector2, _width: float) -> Array[Vector2i]:
	return grid.building_footprint(unit_id, anchor, _width)
func footprint_outline(cells: Array) -> PackedVector2Array:
	return grid.footprint_outline(cells)
func occupy(cells: Array, delta: int) -> void:
	grid.occupy(cells, delta)
func register_gate(gate: Dictionary) -> void:
	grid.register_gate(gate)
func set_gate_open(gate: Dictionary, opened: bool) -> void:
	grid.set_gate_open(gate, opened)
func remove_gate(gate: Dictionary) -> void:
	grid.remove_gate(gate)
func _refresh_gate_points() -> void:
	grid._refresh_gate_points()
func rebuild_buildings(units: Array) -> void:
	grid.rebuild_buildings(units)
