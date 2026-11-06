extends RefCounted
## Save-codec adapter over a scene-free domain graph.
const SIM_DT = preload("res://simulation/battle_config.gd").SIM_DT
var world := preload("res://simulation/battle_world.gd").new()
var state = world.state
var _modules: Dictionary = world._modules
var commands: RefCounted:
	get: return self
var view = null
var saver: RefCounted
var ai: RefCounted:
	get: return state.ai
	set(value): state.ai = value

func _get(key: StringName):
	return state.get(key)

func _set(key: StringName, value) -> bool:
	state.set(key, value)
	return true

func prepare(source: RefCounted, definition: Dictionary = {}) -> bool:
	preload("res://simulation/battle_state_fields.gd").copy_inputs(source, state)
	world.set_definition(definition if not definition.is_empty() else source.map_data)
	state.map_data = world.definition.duplicate(true)
	var registry := world.connect_services("snapshot")
	if not registry.conflicts.is_empty() or not registry.missing.is_empty(): return false
	state.nav.setup(state.map_data)
	state.visibility.setup(Vector2(float(state.map_data.terrainW), float(state.map_data.terrainH)))
	state.command_rules = preload("res://simulation/systems/command_rules.gd").new(world)
	state.player_commands = preload("res://simulation/systems/player_commands.gd").new(world)
	state.rules = preload("res://simulation/systems/scenario_rules.gd").new(world)
	if source.ai != null: state.ai = preload("res://simulation/systems/ai.gd").new(world)
	saver = preload("res://app/save_service.gd").new(self)
	return true

func dispose() -> void:
	saver = null
	if world != null: world.dispose()

func _apply_tech_bonuses(u: Dictionary) -> void:
	_modules["technology"]._apply_tech_bonuses(u)

func _officer_by_index(idx: int) -> Dictionary:
	return _modules["officer_pool"]._officer_by_index(idx)

func _officer_pool_state() -> Dictionary:
	return _modules["officer_pool"]._officer_pool_state()

func _restore_officer_pool(state: Dictionary) -> void:
	_modules["officer_pool"]._restore_officer_pool(state)

func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	return _modules["entity_factory"]._spawn_unit(unit_id, owner, ax, ay, restoring)

func _build_decor_targets() -> void:
	_modules["harvest_orders"]._build_decor_targets()

func _rebuild_unit_index() -> void:
	_modules["spatial_index"]._rebuild_unit_index()

func _remove_decor(obj: Dictionary) -> void:
	_modules["harvest_orders"]._remove_decor(obj)

func _reset_jimou() -> void:
	_modules["abilities"]._reset_jimou()

func _enforce_team_limits() -> void:
	_modules["command_groups"]._enforce_team_limits()

func _place_unit(u: Dictionary) -> void:
	_modules["battle_simulation"]._place_unit(u)

func _update_gates() -> void:
	_modules["battle_simulation"]._update_gates()

func _free_unit_at(i: int) -> void:
	_modules["battle_simulation"]._free_unit_at(i)

func _resolve_navigation_overlaps() -> void:
	_modules["movement"]._resolve_navigation_overlaps()

func _update_visual(u: Dictionary) -> void:
	_modules["battle_simulation"]._update_visual(u)
