extends "res://named_port.gd"
## harvesting: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


const CARRY_CAPACITY = Config.CARRY_CAPACITY

const SIM_DT = Config.SIM_DT

var economy:
	get: return battle.economy
	set(value): battle.economy = value

var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

func _begin_gather(worker: Dictionary, obj: Dictionary, path: Array) -> void:
	_require(_provider_harvest_orders, "harvest_orders")._begin_gather(worker, obj, path)

func _clicked_harvest_patch(target: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._clicked_harvest_patch(target, worker, reserved)

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_choice(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	_require(_provider_combat, "combat")._kill(u, by)

func _nearest_harvest_by_path(worker: Dictionary, kind: String, reserved: Dictionary = {}, exclude: Array = []) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._nearest_harvest_by_path(worker, kind, reserved, exclude)

func _remove_decor(obj: Dictionary) -> void:
	_require(_provider_harvest_orders, "harvest_orders")._remove_decor(obj)

func _yield_of(unit_id: int) -> String:
	return _require(_provider_harvest_orders, "harvest_orders")._yield_of(unit_id)

const CONTRACTS := {"battle_simulation": ["_feedback"], "combat": ["_kill"], "harvest_orders": ["_begin_gather", "_clicked_harvest_patch", "_nearest_harvest_by_path", "_remove_decor", "_yield_of"], "interaction_paths": ["_edge_interaction_choice"]}
var _provider_battle_simulation: WeakRef
var _provider_combat: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_interaction_paths: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_combat = null
	_provider_harvest_orders = null
	_provider_interaction_paths = null
