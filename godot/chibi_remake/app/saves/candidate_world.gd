extends RefCounted
## Save-codec adapter over a scene-free domain graph.
const SIM_DT = preload("res://simulation/battle_config.gd").SIM_DT
var world := preload("res://simulation/battle_world.gd").new()
var state = world.state
var commands := preload("res://app/battle_commands.gd").new()
var view = null
var saver: RefCounted
var ai: RefCounted:
	get: return state.ai
	set(value): state.ai = value

func _get(key: StringName):
	if key in state.PROXY_FIELDS: return state.get(key)
	preload("res://property_contract.gd").reject(self,key)
	return null

func _set(key: StringName, value) -> bool:
	if key not in state.PROXY_FIELDS:
		preload("res://property_contract.gd").reject(self,key)
		return false
	state.set(key, value)
	return true

func prepare(source: RefCounted, definition: Dictionary = {}) -> bool:
	preload("res://simulation/battle_state_fields.gd").copy_inputs(source, state)
	world.set_definition(definition if not definition.is_empty() else source.map_data)
	state.map_data = world.definition.duplicate(true)
	var access := {}
	# Candidates expose simulation commands only, and never construct application services.
	for key in commands.port_objects():
		if key != "commands.session": access[key] = commands.port_objects()[key]
	var report: Dictionary = world.connect_services("snapshot", access, {}, false)
	if not report.missing.is_empty(): return false
	world.prepare_map()
	world.set_ai_enabled(source.ai != null)

	saver = preload("res://app/save_service.gd").new(self)
	return true

func dispose() -> void:
	saver = null
	commands.disconnect_services()
	if world != null: world.dispose()
