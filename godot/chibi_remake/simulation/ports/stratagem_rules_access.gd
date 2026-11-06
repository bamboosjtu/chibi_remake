extends "res://named_port.gd"
## stratagem_rules: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var tile_w:
	get: return battle.tile_w
	set(value): battle.tile_w = value

var units:
	get: return battle.units
	set(value): battle.units = value

var visibility:
	get: return battle.visibility
	set(value): battle.visibility = value

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _hostile_owners(a: int, b: int) -> bool:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return false
	return provider._hostile_owners(a, b)

const CONTRACTS := {"combat": ["_hostile_owners"], "command_groups": ["_commander_for"]}
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_combat = null
	_provider_command_groups = null
