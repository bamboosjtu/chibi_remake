extends "res://named_port.gd"
## construction_orders: explicit callable dependencies; no battle scene reference.


func _anchor_of(a: int, b: int) -> Vector2:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2.ZERO
	return provider._anchor_of(a, b)

func _army_count(owner: int) -> int:
	var provider = _require(_provider_production, "production")
	if provider == null: return 0
	return provider._army_count(owner)

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _cell_of_px(px: float, py: float) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._cell_of_px(px, py)

func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return {}
	return provider._cell_unit(cell, exclude_uid, layer)

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cmd_begin(kind, data)

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _construction_workers(commander: Dictionary) -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._construction_workers(commander)

func _dock_can_launch(point: Vector2) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider._dock_can_launch(point)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0
	return provider._edge_cell_distance(u, o)

func _edge_neighbors(o: Dictionary, exclude_uid := -1, require_free := false, owner := -1) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._edge_neighbors(o, exclude_uid, require_free, owner)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _footprint_cells(o: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._footprint_cells(o)

func _free_unit_at(i: int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._free_unit_at(i)

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._grant_officer_exp(u, amount)

func _interaction_path(u: Dictionary, obj: Dictionary, reach: float) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._interaction_path(u, obj, reach)

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._kill(u, by)

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return {}
	return provider._make_unit(ob, is_map_object)

func _nav_layer(u: Dictionary) -> int:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return 0
	return provider._nav_layer(u)

func _near_walkable(c: Vector2i) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._near_walkable(c)

func _selected_construction_workers() -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._selected_construction_workers()

func _selected_workers() -> Array:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return []
	return provider._selected_workers()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return ""
	return provider._sheet_ref_for(unit_id, owner)

func _target_sync(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._target_sync(u)

func ai_can_build(owner: int, building_type: int) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider.ai_can_build(owner, building_type)

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider.ai_production_building(owner, requested_unit)

func ai_unit_cost(unit_id: int) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider.ai_unit_cost(unit_id)

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
	_provider_ai_economy = weakref(services["ai_economy"]) if services.get("ai_economy") != null else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.get("entity_factory") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	_provider_production = weakref(services["production"]) if services.get("production") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
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
