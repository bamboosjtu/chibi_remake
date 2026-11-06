extends "res://named_port.gd"
## interaction_paths: explicit callable dependencies; no battle scene reference.


func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	return _require(_provider_spatial_index, "spatial_index")._cell_unit(cell, exclude_uid, layer)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)

func _unit_cell(u: Dictionary) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._unit_cell(u)

func _yield_of(unit_id: int) -> String:
	return _require(_provider_harvest_orders, "harvest_orders")._yield_of(unit_id)

const CONTRACTS := {"command_groups": ["_nav_layer"], "harvest_orders": ["_yield_of"], "movement": ["_path_to"], "spatial_index": ["_cell_unit", "_unit_cell"]}
var _provider_command_groups: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_movement: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_groups = null
	_provider_harvest_orders = null
	_provider_movement = null
	_provider_spatial_index = null
