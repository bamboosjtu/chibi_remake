extends "res://named_port.gd"
## scenario_rules: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var map_data:
	get: return battle.map_data
	set(value): battle.map_data = value

var nav:
	get: return battle.nav
	set(value): battle.nav = value

var objective_done:
	get: return battle.objective_done
	set(value): battle.objective_done = value

var officer_progress:
	get: return battle.officer_progress
	set(value): battle.officer_progress = value

var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

var scenario_mission:
	get: return battle.scenario_mission
	set(value): battle.scenario_mission = value

var scenario_sides:
	get: return battle.scenario_sides
	set(value): battle.scenario_sides = value

var sim_tick:
	get: return battle.sim_tick
	set(value): battle.sim_tick = value

var task_events:
	get: return battle.task_events
	set(value): battle.task_events = value

var task_latches:
	get: return battle.task_latches
	set(value): battle.task_latches = value

var terrain_changes:
	get: return battle.terrain_changes
	set(value): battle.terrain_changes = value

var units:
	get: return battle.units
	set(value): battle.units = value

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	_require(_provider_officer_teams, "officer_teams")._grant_officer_exp(u, amount)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

const CONTRACTS := {"command_groups": ["_nav_layer"], "officer_teams": ["_grant_officer_exp"]}
var _provider_command_groups: WeakRef
var _provider_officer_teams: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.has("officer_teams") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_groups = null
	_provider_officer_teams = null
