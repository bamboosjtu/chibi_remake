extends "res://named_port.gd"
## economy: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


const CARRY_CAPACITY = Config.CARRY_CAPACITY

var ai_res:
	get: return battle.ai_res
	set(value): battle.ai_res = value

var food:
	get: return battle.food
	set(value): battle.food = value

var gold:
	get: return battle.gold
	set(value): battle.gold = value

var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

var stone:
	get: return battle.stone
	set(value): battle.stone = value

var wood:
	get: return battle.wood
	set(value): battle.wood = value

func _ai_res_of(owner: int) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider._ai_res_of(owner)

func _deposit_ready(u: Dictionary, o: Dictionary) -> bool:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return false
	return provider._deposit_ready(u, o)

func _deposits_for(u: Dictionary, kind: String) -> Array:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return []
	return provider._deposits_for(u, kind)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _food_capacity(owner: int) -> float:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return 0.0
	return provider._food_capacity(owner)

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._grant_officer_exp(u, amount)

func _resources() -> Dictionary:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return {}
	return provider._resources()

const CONTRACTS := {"ai_economy": ["_ai_res_of"], "battle_simulation": ["_feedback", "_resources"], "harvest_orders": ["_deposits_for", "_food_capacity"], "interaction_paths": ["_deposit_ready"], "officer_teams": ["_grant_officer_exp"]}
var _provider_ai_economy: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_officer_teams: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.get("ai_economy") != null else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_battle_simulation = null
	_provider_harvest_orders = null
	_provider_interaction_paths = null
	_provider_officer_teams = null
