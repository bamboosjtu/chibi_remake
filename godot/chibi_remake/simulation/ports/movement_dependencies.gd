extends "res://named_port.gd"
## movement: explicit callable dependencies; no battle scene reference.


func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _footprint_cells(o: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._footprint_cells(o)

func _nav_layer(u: Dictionary) -> int:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return 0
	return provider._nav_layer(u)

func _place_unit(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._place_unit(u)

func _spd_mult(u: Dictionary) -> float:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return 0.0
	return provider._spd_mult(u)

func _unit_cell(u: Dictionary) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._unit_cell(u)

func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._unit_placement_free(anchor, unit_id, layer, exclude_uid)

const CONTRACTS := {"abilities": ["_spd_mult"], "battle_simulation": ["_feedback", "_place_unit"], "command_groups": ["_cancel_unit_command", "_nav_layer"], "interaction_paths": ["_footprint_cells"], "spatial_index": ["_unit_cell", "_unit_placement_free"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.get("abilities") != null else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_interaction_paths = null
	_provider_spatial_index = null
