extends "res://named_port.gd"
## unit_actions: explicit callable dependencies; no battle scene reference.



func _attach_to_ship(u: Dictionary, ship: Dictionary) -> bool:
	return _require(_provider_transport_orders, "transport_orders")._attach_to_ship(u, ship)

func _auto_assign_new_team(officer_index: int) -> void:
	_require(_provider_officer_teams, "officer_teams")._auto_assign_new_team(officer_index)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _deposit_carry(u: Dictionary) -> bool:
	return _require(_provider_harvest_orders, "harvest_orders")._deposit_carry(u)

func _deposit_ready(u: Dictionary, o: Dictionary) -> bool:
	return _require(_provider_interaction_paths, "interaction_paths")._deposit_ready(u, o)

func _deposits_for(u: Dictionary, kind: String) -> Array:
	return _require(_provider_harvest_orders, "harvest_orders")._deposits_for(u, kind)

func _dist_to_obj(u: Dictionary, o: Dictionary) -> float:
	return _require(_provider_interaction_paths, "interaction_paths")._dist_to_obj(u, o)

func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._do_repair(w, t)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_cell_distance(u, o)

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_choice(u, o, reserved, max_body)

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_path(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _fire_attack(attacker: Dictionary, target: Dictionary) -> void:
	_require(_provider_combat, "combat")._fire_attack(attacker, target)

func _follow(u: Dictionary, delta: float) -> bool:
	return _require(_provider_movement, "movement")._follow(u, delta)

func _interaction_path(u: Dictionary, obj: Dictionary, reach: float) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._interaction_path(u, obj, reach)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	_require(_provider_combat, "combat")._kill(u, by)

func _melee_line_clear(a: Dictionary, b: Dictionary) -> bool:
	return _require(_provider_combat, "combat")._melee_line_clear(a, b)

func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	return _require(_provider_combat, "combat")._nearest_enemy(u, max_d)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)

func _retry_unload(ship: Dictionary) -> int:
	return _require(_provider_transport_orders, "transport_orders")._retry_unload(ship)

func _separate_unit(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._separate_unit(u)

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	return _require(_provider_construction_orders, "construction_orders")._site_entry_path(unit, site, future_cells)

func _unit_cell(u: Dictionary) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._unit_cell(u)

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._valid_build_worker(worker, site)

func _contains_unit(unit: Dictionary) -> bool:
	return _require(_provider_spatial_index, "spatial_index")._contains_unit(unit)

const CONTRACTS := {"battle_simulation": ["_feedback"], "combat": ["_fire_attack", "_kill", "_melee_line_clear", "_nearest_enemy"], "command_groups": ["_cancel_unit_command"], "construction_orders": ["_do_repair", "_site_entry_path", "_valid_build_worker"], "harvest_orders": ["_deposit_carry", "_deposits_for"], "interaction_paths": ["_deposit_ready", "_dist_to_obj", "_edge_cell_distance", "_edge_interaction_choice", "_edge_interaction_path", "_interaction_path"], "movement": ["_follow", "_path_to"], "officer_teams": ["_auto_assign_new_team"], "spatial_index": ["_contains_unit", "_separate_unit", "_unit_cell"], "transport_orders": ["_attach_to_ship", "_retry_unload"]}
var _provider_battle_simulation: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_construction_orders: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_officer_teams: WeakRef
var _provider_spatial_index: WeakRef
var _provider_transport_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.has("construction_orders") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.has("officer_teams") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	_provider_transport_orders = weakref(services["transport_orders"]) if services.has("transport_orders") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_construction_orders = null
	_provider_harvest_orders = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_officer_teams = null
	_provider_spatial_index = null
	_provider_transport_orders = null
