extends RefCounted
## Save-codec adapter over a scene-free domain graph.
const SIM_DT = preload("res://simulation/battle_config.gd").SIM_DT
var world := preload("res://simulation/battle_world.gd").new()
var state = world.state
var _modules: Dictionary = world._modules
var commands := preload("res://app/battle_commands.gd").new()
var view = null
var saver: RefCounted
var ai: RefCounted:
	get: return state.ai
	set(value): state.ai = value

func _get(key: StringName):
	if key in state.PROXY_FIELDS: return state.get(key)
	push_error("Unknown snapshot state property: " + str(key))
	return null

func _set(key: StringName, value) -> bool:
	if key not in state.PROXY_FIELDS:
		push_error("Unknown snapshot state property: " + str(key))
		return false
	state.set(key, value)
	return true

func prepare(source: RefCounted, definition: Dictionary = {}) -> bool:
	preload("res://simulation/battle_state_fields.gd").copy_inputs(source, state)
	world.set_definition(definition if not definition.is_empty() else source.map_data)
	state.map_data = world.definition.duplicate(true)
	var access := world._access.duplicate()
	# Candidates expose simulation commands only, and never construct application services.
	for key in commands.port_objects():
		if key != "commands.session": access[key] = commands.port_objects()[key]
	var report := preload("res://composition_contract.gd").wire(world._modules, "snapshot", access)
	if not report.missing.is_empty(): return false
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
	commands.disconnect_services()
	if world != null: world.dispose()
