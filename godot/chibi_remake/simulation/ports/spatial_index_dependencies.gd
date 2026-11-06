extends "res://named_port.gd"
## spatial_index: explicit callable dependencies; no battle scene reference.


func _footprint_cells(o: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._footprint_cells(o)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _place_unit(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._place_unit(u)

func _spd_mult(u: Dictionary) -> float:
	return _require(_provider_abilities, "abilities")._spd_mult(u)

const CONTRACTS := {"abilities": ["_spd_mult"], "battle_simulation": ["_place_unit"], "command_groups": ["_nav_layer"], "interaction_paths": ["_footprint_cells"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_interaction_paths: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.has("abilities") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_interaction_paths = null
