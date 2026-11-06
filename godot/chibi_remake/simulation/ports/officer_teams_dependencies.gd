extends "res://named_port.gd"
## officer_teams: explicit callable dependencies; no battle scene reference.


func _apply_tech_bonuses(u: Dictionary) -> void:
	_require(_provider_technology, "technology")._apply_tech_bonuses(u)

func _army_count(owner: int) -> int:
	return _require(_provider_production, "production")._army_count(owner)

func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	_require(_provider_entity_factory, "entity_factory")._attach_officer(u, o)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _clear_control_group_for(uid: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._clear_control_group_for(uid)

func _clear_officer_control_groups(officer_index:int, owner:int, leader_uid:int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._clear_officer_control_groups(officer_index, owner, leader_uid)

func _commander_count(owner: int) -> int:
	return _require(_provider_production, "production")._commander_count(owner)

func _commander_for(u: Dictionary) -> Dictionary:
	return _require(_provider_command_groups, "command_groups")._commander_for(u)

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_path(u, o, reserved, max_body)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _free_unit_at(i: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._free_unit_at(i)

func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._free_unit_cell(cell, layer, exclude_uid, unit_id, max_radius)

func _group_units(n: int) -> Array:
	return _require(_provider_command_groups, "command_groups")._group_units(n)

func _is_worker_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_worker_unit(u)

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	return _require(_provider_entity_factory, "entity_factory")._make_unit(ob, is_map_object)

func _officer_by_index(idx: int) -> Dictionary:
	return _require(_provider_officer_pool, "officer_pool")._officer_by_index(idx)

func _officer_held_only_by_selection(idx: int) -> bool:
	return _require(_provider_officer_pool, "officer_pool")._officer_held_only_by_selection(idx)

func _place_unit(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._place_unit(u)

func _reset_jimou() -> void:
	_require(_provider_abilities, "abilities")._reset_jimou()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)

func _sync_officer_to_pool(off: Dictionary) -> void:
	_require(_provider_officer_pool, "officer_pool")._sync_officer_to_pool(off)

func officer_in_use(idx: int) -> bool:
	return _require(_provider_officer_pool, "officer_pool").officer_in_use(idx)

func officer_rank_name(off: Dictionary) -> String:
	return _require(_provider_combat, "combat").officer_rank_name(off)

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
	_provider_abilities = weakref(services["abilities"]) if services.has("abilities") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.has("entity_factory") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	_provider_officer_pool = weakref(services["officer_pool"]) if services.has("officer_pool") else null
	_provider_production = weakref(services["production"]) if services.has("production") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
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
