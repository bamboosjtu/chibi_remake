extends RefCounted
## Save-codec adapter over a scene-free domain graph.
const SIM_DT = preload("res://simulation/battle_config.gd").SIM_DT
var world := preload("res://simulation/battle_world.gd").new()
var state = world.state
var commands := preload("res://app/battle_commands.gd").new()
var saver: RefCounted

func prepare(source: RefCounted, definition: Dictionary = {}) -> bool:
	preload("res://simulation/battle_state_fields.gd").copy_inputs(source, state)
	world.set_definition(definition if not definition.is_empty() else source.map_data)
	state.map_data = world.definition.duplicate(true)
	if not _connect(): return false
	world.prepare_map()
	world.set_ai_enabled(source.ai != null)
	return true

func prepare_map_id(map_id: String) -> String:
	if not _connect(): return "候选战场装配失败"
	var opening := preload("res://app/battle/battle_opening.gd").new(world)
	var error := opening.prepare_map(map_id)
	if not error.is_empty(): return error
	return "" if opening.populate(false) else "地图实体已经初始化"

func _connect() -> bool:
	var access := {}
	# Candidates expose simulation commands only, and never construct application services.
	for key in commands.port_objects():
		if key != "commands.session": access[key] = commands.port_objects()[key]
	var report: Dictionary = world.connect_services("snapshot", access, {}, false)
	if not report.missing.is_empty(): return false
	saver = preload("res://app/save_service.gd").new(self)
	return true

func dispose() -> void:
	saver = null
	commands.disconnect_services()
	if world != null: world.dispose()
