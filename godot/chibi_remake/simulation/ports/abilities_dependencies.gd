extends "res://named_port.gd"
## abilities: explicit callable dependencies; no battle scene reference.


func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)

func _clear_pending() -> void:
	_require(_provider_world_orders, "world_orders")._clear_pending()

func _commander_for(u: Dictionary) -> Dictionary:
	return _require(_provider_command_groups, "command_groups")._commander_for(u)

func _enemy_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._enemy_at(pos)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	_require(_provider_combat, "combat")._kill(u, by)

func _move_unit_to_cell(u: Dictionary, cell: Vector2i) -> bool:
	return _require(_provider_movement, "movement")._move_unit_to_cell(u, cell)

func _player_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._player_at(pos)

const CONTRACTS := {"battle_simulation": ["_feedback"], "combat": ["_kill"], "command_groups": ["_commander_for"], "movement": ["_cell_of_px", "_move_unit_to_cell"], "selection": ["_enemy_at", "_player_at"], "world_orders": ["_clear_pending"]}
var _provider_battle_simulation: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_movement: WeakRef
var _provider_selection: WeakRef
var _provider_world_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_selection = weakref(services["selection"]) if services.has("selection") else null
	_provider_world_orders = weakref(services["world_orders"]) if services.has("world_orders") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_movement = null
	_provider_selection = null
	_provider_world_orders = null
