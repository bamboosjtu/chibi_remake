extends "res://named_port.gd"
## transports: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var map_data:
	get: return battle.map_data
	set(value): battle.map_data = value

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

func _footprint_cells(o: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._footprint_cells(o)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return []
	return provider._path_to(u, target_px, exact)

func _unit_cell(u: Dictionary) -> Vector2i:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return Vector2i.ZERO
	return provider._unit_cell(u)

func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return false
	return provider._unit_placement_free(anchor, unit_id, layer, exclude_uid)

const CONTRACTS := {"command_groups": ["_cancel_unit_command"], "interaction_paths": ["_footprint_cells"], "movement": ["_path_to"], "spatial_index": ["_unit_cell", "_unit_placement_free"]}
var _provider_command_groups: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_groups = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_spatial_index = null
