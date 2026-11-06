extends "res://named_port.gd"
## harvest_orders: explicit callable dependencies; no battle scene reference.


func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_choice(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _is_worker_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_worker_unit(u)

func _reachable_resource_for(u: Dictionary, reserved := {}) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._reachable_resource_for(u, reserved)

func _resource_patch_cells(target: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._resource_patch_cells(target)

func _resource_patch_interaction_choice(u: Dictionary, target: Dictionary, reserved := {}, known_cells: Array = []) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._resource_patch_interaction_choice(u, target, reserved, known_cells)

func _unit_cell(u: Dictionary) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._unit_cell(u)

const CONTRACTS := {"battle_simulation": ["_feedback"], "command_groups": ["_cancel_unit_command"], "interaction_paths": ["_edge_interaction_choice", "_reachable_resource_for", "_resource_patch_cells", "_resource_patch_interaction_choice"], "spatial_index": ["_unit_cell"], "technology": ["_is_worker_unit"]}
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_interaction_paths = null
	_provider_spatial_index = null
	_provider_technology = null
