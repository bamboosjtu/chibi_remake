extends "res://named_port.gd"
## world: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"battle_simulation": ["_feedback", "_finish_death", "_free_unit_at", "_place_unit", "_prune_dead", "_resources", "_set_frame", "_sim_step", "_state_digest", "_update_gates", "_update_visual", "set_sim_speed"], "entity_factory": ["_attach_officer", "_sheet_ref_for", "_spawn_unit"], "spatial_index": ["_cell_unit", "_free_unit_cell", "_index_eligible", "_index_sync", "_rebuild_unit_index", "_separate_unit", "_unit_cell", "_unit_placement_free"], "campaign": ["_check_end", "_force_counts", "_objective_kind", "_show_end", "_unit_name", "_water_cell_count"]}
var _provider_battle_simulation: WeakRef
var _provider_entity_factory: WeakRef
var _provider_spatial_index: WeakRef
var _provider_campaign: WeakRef

func _feedback(msg: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(msg)

func _resources() -> Dictionary:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return {}
	return provider._resources()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return ""
	return provider._sheet_ref_for(unit_id, owner)

func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return false
	return provider._spawn_unit(unit_id, owner, ax, ay, restoring)

func _unit_cell(u: Dictionary) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._unit_cell(u)

func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return {}
	return provider._cell_unit(cell, exclude_uid, layer)

func _index_eligible(u: Dictionary) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._index_eligible(u)

func _index_sync(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._index_sync(u)

func _rebuild_unit_index() -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._rebuild_unit_index()

func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._unit_placement_free(anchor, unit_id, layer, exclude_uid)

func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._free_unit_cell(cell, layer, exclude_uid, unit_id, max_radius)

func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	var provider = _require(_provider_entity_factory, "entity_factory")
	if provider == null: return
	provider._attach_officer(u, o)

func set_sim_speed(index: int) -> bool:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return false
	return provider.set_sim_speed(index)

func _show_end(kind: int) -> void:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return
	provider._show_end(kind)

func _place_unit(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._place_unit(u)

func _finish_death(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._finish_death(u)

func _update_gates() -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._update_gates()

func _sim_step(dt: float) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._sim_step(dt)

func _state_digest() -> int:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return 0
	return provider._state_digest()

func _prune_dead() -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._prune_dead()

func _free_unit_at(i: int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._free_unit_at(i)

func _separate_unit(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._separate_unit(u)

func _update_visual(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._update_visual(u)

func _set_frame(u: Dictionary, f: int) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._set_frame(u, f)

func _force_counts(owner: int) -> Dictionary:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return {}
	return provider._force_counts(owner)

func _objective_kind() -> String:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return ""
	return provider._objective_kind()

func _water_cell_count() -> int:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return 0
	return provider._water_cell_count()

func _check_end() -> void:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return
	provider._check_end()

func _unit_name(unit_id: int) -> String:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return ""
	return provider._unit_name(unit_id)

func connect_services(services: Dictionary) -> Array:
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.get("entity_factory") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_campaign = weakref(services["campaign"]) if services.get("campaign") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_entity_factory = null
	_provider_spatial_index = null
	_provider_campaign = null
