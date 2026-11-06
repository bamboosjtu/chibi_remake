extends "res://named_port.gd"
## transport_orders: explicit callable dependencies; no battle scene reference.


func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _command_units() -> Array:
	return _require(_provider_command_groups, "command_groups")._command_units()

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _index_forget(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._index_forget(u)

func _is_naval(u: Dictionary) -> bool:
	return _require(_provider_command_groups, "command_groups")._is_naval(u)

func _place_unit(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._place_unit(u)

func _reset_jimou() -> void:
	_require(_provider_abilities, "abilities")._reset_jimou()

func _target_forget(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._target_forget(u)

const CONTRACTS := {"abilities": ["_reset_jimou"], "battle_simulation": ["_feedback", "_place_unit"], "command_groups": ["_cancel_unit_command", "_command_units", "_is_naval"], "spatial_index": ["_index_forget", "_target_forget"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.has("abilities") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_spatial_index = null
