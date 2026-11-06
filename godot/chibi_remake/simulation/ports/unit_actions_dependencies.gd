extends "res://named_port.gd"
## unit_actions: explicit callable dependencies; no battle scene reference.



func _attach_to_ship(u: Dictionary, ship: Dictionary) -> bool:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return false
	return provider._attach_to_ship(u, ship)

func _auto_assign_new_team(officer_index: int) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._auto_assign_new_team(officer_index)

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _deposit_carry(u: Dictionary) -> bool:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return false
	return provider._deposit_carry(u)

func _deposit_ready(u: Dictionary, o: Dictionary) -> bool:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return false
	return provider._deposit_ready(u, o)

func _deposits_for(u: Dictionary, kind: String) -> Array:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return []
	return provider._deposits_for(u, kind)

func _dist_to_obj(u: Dictionary, o: Dictionary) -> float:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0.0
	return provider._dist_to_obj(u, o)

func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._do_repair(w, t)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0
	return provider._edge_cell_distance(u, o)

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return {}
	return provider._edge_interaction_choice(u, o, reserved, max_body)

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._edge_interaction_path(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _fire_attack(attacker: Dictionary, target: Dictionary) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._fire_attack(attacker, target)

func _follow(u: Dictionary, delta: float) -> bool:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return false
	return provider._follow(u, delta)

func _interaction_path(u: Dictionary, obj: Dictionary, reach: float) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._interaction_path(u, obj, reach)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._kill(u, by)

func _melee_line_clear(a: Dictionary, b: Dictionary) -> bool:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return false
	return provider._melee_line_clear(a, b)

func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return {}
	return provider._nearest_enemy(u, max_d)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return []
	return provider._path_to(u, target_px, exact)

func _retry_unload(ship: Dictionary) -> int:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return 0
	return provider._retry_unload(ship)

func _separate_unit(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._separate_unit(u)

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return []
	return provider._site_entry_path(unit, site, future_cells)

func _unit_cell(u: Dictionary) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._unit_cell(u)

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._valid_build_worker(worker, site)

func _contains_unit(unit: Dictionary) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._contains_unit(unit)

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
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.get("construction_orders") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_transport_orders = weakref(services["transport_orders"]) if services.get("transport_orders") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
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
