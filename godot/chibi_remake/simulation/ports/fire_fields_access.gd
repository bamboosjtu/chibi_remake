extends "res://named_port.gd"
## fire_fields: only the state and commands required by this system.
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

var units:
	get: return battle.units
	set(value): battle.units = value

func _apply_hit(target: Dictionary, damage: float, source_uid: int) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._apply_hit(target, damage, source_uid)

func _cell_of_px(px: float, py: float) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._cell_of_px(px, py)

func _footprint_cells(o: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._footprint_cells(o)

const CONTRACTS := {"combat": ["_apply_hit"], "interaction_paths": ["_footprint_cells"], "movement": ["_cell_of_px"]}
var _provider_combat: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_combat = null
	_provider_interaction_paths = null
	_provider_movement = null
