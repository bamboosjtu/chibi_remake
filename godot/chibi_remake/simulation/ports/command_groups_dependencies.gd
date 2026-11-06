extends "res://named_port.gd"
## command_groups: explicit callable dependencies; no battle scene reference.


func _clear_pending() -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._clear_pending()

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _order_disband() -> int:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return 0
	return provider._order_disband()

func _reset_jimou() -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._reset_jimou()

func _unload_selected() -> void:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return
	provider._unload_selected()

const CONTRACTS := {"abilities": ["_reset_jimou"], "battle_simulation": ["_feedback"], "officer_teams": ["_order_disband"], "technology": ["_is_worker_unit"], "transport_orders": ["_unload_selected"], "world_orders": ["_clear_pending"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_officer_teams: WeakRef
var _provider_technology: WeakRef
var _provider_transport_orders: WeakRef
var _provider_world_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.get("abilities") != null else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	_provider_transport_orders = weakref(services["transport_orders"]) if services.get("transport_orders") != null else null
	_provider_world_orders = weakref(services["world_orders"]) if services.get("world_orders") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_officer_teams = null
	_provider_technology = null
	_provider_transport_orders = null
	_provider_world_orders = null
