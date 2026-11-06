extends "res://named_port.gd"
## scene_controller: explicit callable dependencies; no battle scene reference.

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _group_assign(n: int) -> void:
	_require(_provider_command_groups, "command_groups")._group_assign(n)

func _group_recall(n: int) -> bool:
	return _require(_provider_command_groups, "command_groups")._group_recall(n)

func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	return _require(_provider_combat, "combat")._nearest_enemy(u, max_d)

func _order_at(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._order_at(pos)

func _order_context(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._order_context(pos)

func _order_gather(target_obj: Dictionary) -> int:
	return _require(_provider_harvest_orders, "harvest_orders")._order_gather(target_obj)

func _resource_at(pos: Vector2) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._resource_at(pos)

func _resources() -> Dictionary:
	return _require(_provider_battle_simulation, "battle_simulation")._resources()

func _select_box(rect: Rect2, add: bool) -> void:
	_require(_provider_selection, "selection")._select_box(rect, add)

func _select_click(pos: Vector2, add: bool) -> void:
	_require(_provider_selection, "selection")._select_click(pos, add)

func _sim_step(dt: float) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._sim_step(dt)

func _state_digest() -> int:
	return _require(_provider_battle_simulation, "battle_simulation")._state_digest()

func cmd_pending_kind() -> String:
	return _require(_provider_world_orders, "world_orders").cmd_pending_kind()

func handle_cheat_input(event: InputEvent) -> bool:
	return _require(_provider_cheat_controller, "cheat_controller").handle_cheat_input(event)

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
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_cheat_controller = weakref(services["cheat_controller"]) if services.has("cheat_controller") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_selection = weakref(services["selection"]) if services.has("selection") else null
	_provider_world_orders = weakref(services["world_orders"]) if services.has("world_orders") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_cheat_controller = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_harvest_orders = null
	_provider_selection = null
	_provider_world_orders = null
