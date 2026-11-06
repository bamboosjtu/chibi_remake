extends "res://named_port.gd"
## scene_controller: explicit callable dependencies; no battle scene reference.

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _group_assign(n: int) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._group_assign(n)

func _group_recall(n: int) -> bool:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return false
	return provider._group_recall(n)

func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return {}
	return provider._nearest_enemy(u, max_d)

func _order_at(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._order_at(pos)

func _order_context(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._order_context(pos)

func _order_gather(target_obj: Dictionary) -> int:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return 0
	return provider._order_gather(target_obj)

func _resource_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._resource_at(pos)

func _resources() -> Dictionary:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return {}
	return provider._resources()

func _select_box(rect: Rect2, add: bool) -> void:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return
	provider._select_box(rect, add)

func _select_click(pos: Vector2, add: bool) -> void:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return
	provider._select_click(pos, add)

func _sim_step(dt: float) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._sim_step(dt)

func _state_digest() -> int:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return 0
	return provider._state_digest()

func cmd_pending_kind() -> String:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return ""
	return provider.cmd_pending_kind()

func handle_cheat_input(event: InputEvent) -> bool:
	var provider = _require(_provider_cheat_controller, "cheat_controller")
	if provider == null: return false
	return provider.handle_cheat_input(event)

const CONTRACTS := {"battle_simulation": ["_feedback", "_resources", "_sim_step", "_state_digest"], "cheat_controller": ["handle_cheat_input"], "combat": ["_nearest_enemy"], "command_groups": ["_group_assign", "_group_recall"], "harvest_orders": ["_order_gather", "_resource_at"], "selection": ["_select_box", "_select_click"], "world_orders": ["_order_at", "_order_context", "cmd_pending_kind"]}
var _provider_battle_simulation: WeakRef
var _provider_cheat_controller: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_selection: WeakRef
var _provider_world_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_cheat_controller = weakref(services["cheat_controller"]) if services.get("cheat_controller") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_selection = weakref(services["selection"]) if services.get("selection") != null else null
	_provider_world_orders = weakref(services["world_orders"]) if services.get("world_orders") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_cheat_controller = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_harvest_orders = null
	_provider_selection = null
	_provider_world_orders = null
