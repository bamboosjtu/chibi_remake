extends RefCounted
const WorldInputs = preload("res://simulation/world/world_inputs.gd")
## Save-codec adapter over a scene-free domain graph.
const SIM_DT = preload("res://simulation/definitions/battle_config.gd").SIM_DT
var world := preload("res://simulation/world/battle_world.gd").new()
var state = world.state
var saver: RefCounted

func prepare(source: RefCounted, definition: Dictionary = {}) -> bool:
	preload("res://simulation/state/battle_state_fields.gd").copy_inputs(source.state, state)
	world.set_definition(definition if not definition.is_empty() else source.state.map_data)
	WorldInputs.set_map_data(state, world.definition.duplicate(true))
	if not _connect(): return false
	world.prepare_map()
	world.set_ai_enabled(source.ai != null)
	return true

func prepare_map_id(map_id: String) -> String:
	if not _connect(): return "候选战场装配失败"
	var opening := preload("res://app/battle/startup/battle_opening.gd").new(world)
	var error := opening.prepare_map(map_id)
	if not error.is_empty(): return error
	return "" if opening.populate(false) else "地图实体已经初始化"

func _connect() -> bool:
	var report: Dictionary = world.validate_services("snapshot", {}, false)
	if not report.missing.is_empty(): return false
	saver = preload("res://app/saves/save_service.gd").new(self)
	return true

func dispose() -> void:
	saver = null
	if world != null: world.dispose()

func _get(key: StringName):
	if key in ["economy", "projectiles", "fire_fields", "transports", "harvesting", "construction", "stratagems", "command_rules", "rules", "player_commands", "ai", "effects", "nav", "visibility", "automatic_gates", "clock"]: return world.get(key)
	if key in state.PROXY_FIELDS: return state.get(key)
	return null
