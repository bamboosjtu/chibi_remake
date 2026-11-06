extends "res://named_port.gd"
## command_rules: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

var selected:
	get: return battle.selected
	set(value): battle.selected = value

var units:
	get: return battle.units
	set(value): battle.units = value

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _selected_construction_workers() -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._selected_construction_workers()

const CONTRACTS := {"command_groups": ["_commander_for", "_selected_construction_workers"], "technology": ["_is_worker_unit"]}
var _provider_command_groups: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_groups = null
	_provider_technology = null
