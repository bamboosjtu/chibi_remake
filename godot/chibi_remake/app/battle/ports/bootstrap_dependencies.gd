extends "res://named_port.gd"
## bootstrap: explicit callable dependencies; no battle scene reference.

func _apply_save() -> bool:
	return _require(_provider_scene_controller, "scene_controller")._apply_save()

func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	_require(_provider_entity_factory, "entity_factory")._attach_officer(u, o)

func _build_decor_targets() -> void:
	_require(_provider_harvest_orders, "harvest_orders")._build_decor_targets()

func _build_terrain() -> void:
	_require(_provider_scene_controller, "scene_controller")._build_terrain()

func _build_ui() -> void:
	_require(_provider_scene_controller, "scene_controller")._build_ui()

func _demo() -> void:
	_require(_provider_scene_controller, "scene_controller")._demo()

func _fatal(msg: String) -> void:
	_require(_provider_scene_controller, "scene_controller")._fatal(msg)

func _group_assign(n: int) -> void:
	_require(_provider_command_groups, "command_groups")._group_assign(n)

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	return _require(_provider_entity_factory, "entity_factory")._make_unit(ob, is_map_object)

func _officer_by_index(idx: int) -> Dictionary:
	return _require(_provider_officer_pool, "officer_pool")._officer_by_index(idx)

func _officer_pool_state() -> Dictionary:
	return _require(_provider_officer_pool, "officer_pool")._officer_pool_state()

func _rebuild_unit_index() -> void:
	_require(_provider_spatial_index, "spatial_index")._rebuild_unit_index()

func _resolve_navigation_overlaps() -> void:
	_require(_provider_movement, "movement")._resolve_navigation_overlaps()

func _screenshot() -> void:
	_require(_provider_scene_controller, "scene_controller")._screenshot()

func _setup_camera() -> void:
	_require(_provider_scene_controller, "scene_controller")._setup_camera()

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)

func _show_end(kind: int) -> void:
	_require(_provider_campaign, "campaign")._show_end(kind)

func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	return _require(_provider_entity_factory, "entity_factory")._spawn_unit(unit_id, owner, ax, ay, restoring)

func _update_gates() -> void:
	_require(_provider_battle_simulation, "battle_simulation")._update_gates()

func _write_smoke(ok: bool, why: String) -> void:
	_require(_provider_scene_controller, "scene_controller")._write_smoke(ok, why)

const CONTRACTS := {"battle_simulation": ["_update_gates"], "campaign": ["_show_end"], "command_groups": ["_group_assign"], "entity_factory": ["_attach_officer", "_make_unit", "_sheet_ref_for", "_spawn_unit"], "harvest_orders": ["_build_decor_targets"], "movement": ["_resolve_navigation_overlaps"], "officer_pool": ["_officer_by_index", "_officer_pool_state"], "scene_controller": ["_apply_save", "_build_terrain", "_build_ui", "_demo", "_fatal", "_screenshot", "_setup_camera", "_write_smoke"], "spatial_index": ["_rebuild_unit_index"]}
var _provider_battle_simulation: WeakRef
var _provider_campaign: WeakRef
var _provider_command_groups: WeakRef
var _provider_entity_factory: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_movement: WeakRef
var _provider_officer_pool: WeakRef
var _provider_scene_controller: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_campaign = weakref(services["campaign"]) if services.has("campaign") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.has("entity_factory") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_officer_pool = weakref(services["officer_pool"]) if services.has("officer_pool") else null
	_provider_scene_controller = weakref(services["scene_controller"]) if services.has("scene_controller") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_campaign = null
	_provider_command_groups = null
	_provider_entity_factory = null
	_provider_harvest_orders = null
	_provider_movement = null
	_provider_officer_pool = null
	_provider_scene_controller = null
	_provider_spatial_index = null
