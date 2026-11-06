extends "res://named_port.gd"
## construction_orders: explicit callable dependencies; no battle scene reference.


func _anchor_of(a: int, b: int) -> Vector2:
	return _require(_provider_movement, "movement")._anchor_of(a, b)

func _army_count(owner: int) -> int:
	return _require(_provider_production, "production")._army_count(owner)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)

func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	return _require(_provider_spatial_index, "spatial_index")._cell_unit(cell, exclude_uid, layer)

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	_require(_provider_command_groups, "command_groups")._cmd_begin(kind, data)

func _commander_for(u: Dictionary) -> Dictionary:
	return _require(_provider_command_groups, "command_groups")._commander_for(u)

func _construction_workers(commander: Dictionary) -> Array:
	return _require(_provider_command_groups, "command_groups")._construction_workers(commander)

func _dock_can_launch(point: Vector2) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._dock_can_launch(point)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_cell_distance(u, o)

func _edge_neighbors(o: Dictionary, exclude_uid := -1, require_free := false, owner := -1) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_neighbors(o, exclude_uid, require_free, owner)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _footprint_cells(o: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._footprint_cells(o)

func _free_unit_at(i: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._free_unit_at(i)

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	_require(_provider_officer_teams, "officer_teams")._grant_officer_exp(u, amount)

func _interaction_path(u: Dictionary, obj: Dictionary, reach: float) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._interaction_path(u, obj, reach)

func _is_worker_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_worker_unit(u)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	_require(_provider_combat, "combat")._kill(u, by)

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	return _require(_provider_entity_factory, "entity_factory")._make_unit(ob, is_map_object)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _near_walkable(c: Vector2i) -> Vector2i:
	return _require(_provider_movement, "movement")._near_walkable(c)

func _selected_construction_workers() -> Array:
	return _require(_provider_command_groups, "command_groups")._selected_construction_workers()

func _selected_workers() -> Array:
	return _require(_provider_harvest_orders, "harvest_orders")._selected_workers()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)

func _target_sync(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._target_sync(u)

func ai_can_build(owner: int, building_type: int) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_can_build(owner, building_type)

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_production_building(owner, requested_unit)

func ai_unit_cost(unit_id: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_unit_cost(unit_id)

const CONTRACTS := {"ai_economy": ["_dock_can_launch", "ai_can_build", "ai_production_building", "ai_unit_cost"], "battle_simulation": ["_feedback", "_free_unit_at"], "combat": ["_kill"], "command_groups": ["_cancel_unit_command", "_cmd_begin", "_commander_for", "_construction_workers", "_nav_layer", "_selected_construction_workers"], "entity_factory": ["_make_unit", "_sheet_ref_for"], "harvest_orders": ["_selected_workers"], "interaction_paths": ["_edge_cell_distance", "_edge_neighbors", "_footprint_cells", "_interaction_path"], "movement": ["_anchor_of", "_cell_of_px", "_near_walkable"], "officer_teams": ["_grant_officer_exp"], "production": ["_army_count"], "spatial_index": ["_cell_unit", "_target_sync"], "technology": ["_is_worker_unit"]}
var _provider_ai_economy: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_entity_factory: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_officer_teams: WeakRef
var _provider_production: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.has("ai_economy") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.has("entity_factory") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.has("officer_teams") else null
	_provider_production = weakref(services["production"]) if services.has("production") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_battle_simulation = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_entity_factory = null
	_provider_harvest_orders = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_officer_teams = null
	_provider_production = null
	_provider_spatial_index = null
	_provider_technology = null
