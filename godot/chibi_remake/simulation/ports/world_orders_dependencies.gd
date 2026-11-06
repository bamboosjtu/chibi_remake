extends "res://named_port.gd"
## world_orders: explicit callable dependencies; no battle scene reference.


func _anchor_of_cell(cell: Vector2i) -> Vector2:
	return _require(_provider_movement, "movement")._anchor_of_cell(cell)

func _attack_target_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._attack_target_at(pos)

func _build_site_at(pos: Vector2, opt: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._build_site_at(pos, opt)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)

func _cmd_board_at(pos: Vector2) -> void:
	_require(_provider_transport_orders, "transport_orders")._cmd_board_at(pos)

func _cmd_unload_at(pos: Vector2) -> void:
	_require(_provider_transport_orders, "transport_orders")._cmd_unload_at(pos)

func _command_units() -> Array:
	return _require(_provider_command_groups, "command_groups")._command_units()

func _duel_at(pos: Vector2) -> void:
	_require(_provider_abilities, "abilities")._duel_at(pos)

func _enemy_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._enemy_at(pos)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _formation_target_cell(u: Dictionary, cell: Vector2i) -> Vector2i:
	return _require(_provider_abilities, "abilities")._formation_target_cell(u, cell)

func _is_worker_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_worker_unit(u)

func _jimou_cast_at(pos: Vector2) -> void:
	_require(_provider_abilities, "abilities")._jimou_cast_at(pos)

func _march_destination(unit: Dictionary, target: Vector2, reserved: Dictionary) -> Vector2:
	return _require(_provider_movement, "movement")._march_destination(unit, target, reserved)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _neutral_object_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._neutral_object_at(pos)

func _order_build(site: Dictionary) -> int:
	return _require(_provider_construction_orders, "construction_orders")._order_build(site)

func _order_gather(target_obj: Dictionary) -> int:
	return _require(_provider_harvest_orders, "harvest_orders")._order_gather(target_obj)

func _order_join(target: Dictionary) -> int:
	return _require(_provider_officer_teams, "officer_teams")._order_join(target)

func _order_repair(target: Dictionary) -> int:
	return _require(_provider_construction_orders, "construction_orders")._order_repair(target)

func _own_object_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._own_object_at(pos)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)

func _reset_jimou() -> void:
	_require(_provider_abilities, "abilities")._reset_jimou()

func _resource_at(pos: Vector2) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._resource_at(pos)

const CONTRACTS := {"abilities": ["_duel_at", "_formation_target_cell", "_jimou_cast_at", "_reset_jimou"], "battle_simulation": ["_feedback"], "command_groups": ["_cancel_unit_command", "_command_units", "_nav_layer"], "construction_orders": ["_build_site_at", "_order_build", "_order_repair"], "harvest_orders": ["_order_gather", "_resource_at"], "movement": ["_anchor_of_cell", "_cell_of_px", "_march_destination", "_path_to"], "officer_teams": ["_order_join"], "selection": ["_attack_target_at", "_enemy_at", "_neutral_object_at", "_own_object_at"], "technology": ["_is_worker_unit"], "transport_orders": ["_cmd_board_at", "_cmd_unload_at"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_construction_orders: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_movement: WeakRef
var _provider_officer_teams: WeakRef
var _provider_selection: WeakRef
var _provider_technology: WeakRef
var _provider_transport_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.has("abilities") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.has("construction_orders") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.has("officer_teams") else null
	_provider_selection = weakref(services["selection"]) if services.has("selection") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	_provider_transport_orders = weakref(services["transport_orders"]) if services.has("transport_orders") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_construction_orders = null
	_provider_harvest_orders = null
	_provider_movement = null
	_provider_officer_teams = null
	_provider_selection = null
	_provider_technology = null
	_provider_transport_orders = null
