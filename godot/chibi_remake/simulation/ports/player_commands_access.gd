extends "res://named_port.gd"
## player_commands: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var cmd_pending:
	get: return battle.cmd_pending
	set(value): battle.cmd_pending = value

var cmd_pending_data:
	get: return battle.cmd_pending_data
	set(value): battle.cmd_pending_data = value

var command_rules:
	get: return battle.command_rules
	set(value): battle.command_rules = value

var duel_pending:
	get: return battle.duel_pending
	set(value): battle.duel_pending = value

var jimou_caster:
	get: return battle.jimou_caster
	set(value): battle.jimou_caster = value

var jimou_pending:
	get: return battle.jimou_pending
	set(value): battle.jimou_pending = value

var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

var selected:
	get: return battle.selected
	set(value): battle.selected = value

var units:
	get: return battle.units
	set(value): battle.units = value

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

const CONTRACTS := {"battle_simulation": ["_feedback"]}
var _provider_battle_simulation: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
