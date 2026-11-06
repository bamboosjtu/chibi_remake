extends "res://named_port.gd"
## Navigation sibling capabilities.

func cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_grid, "grid").cell_of_px(px, py)

func neighbors(c: Vector2i) -> Array[Vector2i]:
	return _require(_provider_grid, "grid").neighbors(c)

func _in_bounds(c: Vector2i) -> bool:
	return _require(_provider_grid, "grid")._in_bounds(c)

func near_walkable(c: Vector2i, layer := 0) -> Vector2i:
	return _require(_provider_grid, "grid").near_walkable(c, layer)

func _grid(layer: int) -> AStar2D:
	return _require(_provider_grid, "grid")._grid(layer)

func is_solid(c: Vector2i, layer := 0) -> bool:
	return _require(_provider_grid, "grid").is_solid(c, layer)

func anchor_of(a: int, b: int) -> Vector2:
	return _require(_provider_grid, "grid").anchor_of(a, b)

func _id(c: Vector2i) -> int:
	return _require(_provider_grid, "grid")._id(c)

func _refresh_gate_points() -> void:
	_require(_provider_grid, "grid")._refresh_gate_points()

const CONTRACTS := {"grid": ["_grid", "_id", "_in_bounds", "_refresh_gate_points", "anchor_of", "cell_of_px", "is_solid", "near_walkable", "neighbors"]}
var _provider_grid: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_grid = weakref(services["grid"]) if services.has("grid") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_grid = null
