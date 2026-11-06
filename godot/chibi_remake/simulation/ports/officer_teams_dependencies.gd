extends "res://named_port.gd"
## officer_teams: explicit callable dependencies; no battle scene reference.


func _apply_tech_bonuses(u: Dictionary) -> void:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return
	provider._apply_tech_bonuses(u)

func _army_count(owner: int) -> int:
	var provider = _require(_provider_production, "production")
	if provider == null: return 0
	return provider._army_count(owner)

func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return
	provider._attach_officer(u, o)

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _clear_control_group_for(uid: int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._clear_control_group_for(uid)

func _clear_officer_control_groups(officer_index:int, owner:int, leader_uid:int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._clear_officer_control_groups(officer_index, owner, leader_uid)

func _commander_count(owner: int) -> int:
	var provider = _require(_provider_production, "production")
	if provider == null: return 0
	return provider._commander_count(owner)

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._edge_interaction_path(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _free_unit_at(i: int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._free_unit_at(i)

func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._free_unit_cell(cell, layer, exclude_uid, unit_id, max_radius)

func _group_units(n: int) -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._group_units(n)

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return {}
	return provider._make_unit(ob, is_map_object)

func _officer_by_index(idx: int) -> Dictionary:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return {}
	return provider._officer_by_index(idx)

func _officer_held_only_by_selection(idx: int) -> bool:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return false
	return provider._officer_held_only_by_selection(idx)

func _place_unit(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._place_unit(u)

func _reset_jimou() -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._reset_jimou()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return ""
	return provider._sheet_ref_for(unit_id, owner)

func _sync_officer_to_pool(off: Dictionary) -> void:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return
	provider._sync_officer_to_pool(off)

func officer_in_use(idx: int) -> bool:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return false
	return provider.officer_in_use(idx)

func officer_rank_name(off: Dictionary) -> String:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return ""
	return provider.officer_rank_name(off)

const CONTRACTS := {"abilities": ["_reset_jimou"], "battle_simulation": ["_clear_control_group_for", "_clear_officer_control_groups", "_feedback", "_free_unit_at", "_place_unit"], "command_groups": ["_cancel_unit_command", "_commander_for", "_group_units"], "entity_factory": ["_attach_officer", "_make_unit", "_sheet_ref_for"], "interaction_paths": ["_edge_interaction_path"], "officer_pool": ["_officer_by_index", "_officer_held_only_by_selection", "_sync_officer_to_pool", "officer_in_use"], "production": ["_army_count", "_commander_count"], "spatial_index": ["_free_unit_cell"], "technology": ["_apply_tech_bonuses", "_is_worker_unit"], "combat": ["officer_rank_name"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_entity_factory: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_officer_pool: WeakRef
var _provider_production: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef
var _provider_combat: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.get("abilities") != null else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.get("entity_factory") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_officer_pool = weakref(services["officer_pool"]) if services.get("officer_pool") != null else null
	_provider_production = weakref(services["production"]) if services.get("production") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_entity_factory = null
	_provider_interaction_paths = null
	_provider_officer_pool = null
	_provider_production = null
	_provider_spatial_index = null
	_provider_technology = null
	_provider_combat = null
