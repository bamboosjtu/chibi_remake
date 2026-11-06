extends "res://named_port.gd"
## abilities: explicit callable dependencies; no battle scene reference.


func _cell_of_px(px: float, py: float) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._cell_of_px(px, py)

func _clear_pending() -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._clear_pending()

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _enemy_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._enemy_at(pos)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._kill(u, by)

func _move_unit_to_cell(u: Dictionary, cell: Vector2i) -> bool:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return false
	return provider._move_unit_to_cell(u, cell)

func _player_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._player_at(pos)

const CONTRACTS := {"battle_simulation": ["_feedback"], "combat": ["_kill"], "command_groups": ["_commander_for"], "movement": ["_cell_of_px", "_move_unit_to_cell"], "selection": ["_enemy_at", "_player_at"], "world_orders": ["_clear_pending"]}
var _provider_battle_simulation: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_movement: WeakRef
var _provider_selection: WeakRef
var _provider_world_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_selection = weakref(services["selection"]) if services.get("selection") != null else null
	_provider_world_orders = weakref(services["world_orders"]) if services.get("world_orders") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_movement = null
	_provider_selection = null
	_provider_world_orders = null
