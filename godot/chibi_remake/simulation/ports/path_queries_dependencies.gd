extends "res://named_port.gd"
## Navigation sibling capabilities.

func cell_of_px(px: float, py: float) -> Vector2i:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return Vector2i.ZERO
	return provider.cell_of_px(px, py)

func neighbors(c: Vector2i) -> Array[Vector2i]:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return []
	return provider.neighbors(c)

func _in_bounds(c: Vector2i) -> bool:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return false
	return provider._in_bounds(c)

func near_walkable(c: Vector2i, layer := 0) -> Vector2i:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return Vector2i.ZERO
	return provider.near_walkable(c, layer)

func _grid(layer: int) -> AStar2D:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return null
	return provider._grid(layer)

func is_solid(c: Vector2i, layer := 0) -> bool:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return false
	return provider.is_solid(c, layer)

func anchor_of(a: int, b: int) -> Vector2:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return Vector2.ZERO
	return provider.anchor_of(a, b)

func _id(c: Vector2i) -> int:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return 0
	return provider._id(c)

func _refresh_gate_points() -> void:
	var provider = _require(_provider_grid, "grid")
	if provider == null: return
	provider._refresh_gate_points()

const CONTRACTS := {"grid": ["_grid", "_id", "_in_bounds", "_refresh_gate_points", "anchor_of", "cell_of_px", "is_solid", "near_walkable", "neighbors"]}
var _provider_grid: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_grid = weakref(services["grid"]) if services.get("grid") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_grid = null
