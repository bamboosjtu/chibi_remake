extends "res://named_port.gd"
## construction_interior: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


const BUILD_STEP_HP = Config.BUILD_STEP_HP

const BUILD_STEP_TICKS = Config.BUILD_STEP_TICKS

const EDGE_DISTANCE = Config.EDGE_DISTANCE

const SIM_DT = Config.SIM_DT

var nav:
	get: return battle.nav
	set(value): battle.nav = value

var units:
	get: return battle.units
	set(value): battle.units = value

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _complete_site(site: Dictionary) -> void:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return
	provider._complete_site(site)

func _construction_workers(commander: Dictionary) -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._construction_workers(commander)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0
	return provider._edge_cell_distance(u, o)

func _follow(u: Dictionary, delta: float) -> bool:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return false
	return provider._follow(u, delta)

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _nav_layer(u: Dictionary) -> int:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return 0
	return provider._nav_layer(u)

func _place_unit(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._place_unit(u)

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return []
	return provider._site_entry_path(unit, site, future_cells)

func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._unit_placement_free(anchor, unit_id, layer, exclude_uid)

func _update_visual(u: Dictionary) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._update_visual(u)

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._valid_build_worker(worker, site)

const CONTRACTS := {"battle_simulation": ["_place_unit", "_update_visual"], "command_groups": ["_cancel_unit_command", "_commander_for", "_construction_workers", "_nav_layer"], "construction_orders": ["_complete_site", "_site_entry_path", "_valid_build_worker"], "interaction_paths": ["_edge_cell_distance"], "movement": ["_follow"], "spatial_index": ["_unit_placement_free"], "technology": ["_is_worker_unit"]}
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_construction_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.get("construction_orders") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_construction_orders = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_spatial_index = null
	_provider_technology = null
