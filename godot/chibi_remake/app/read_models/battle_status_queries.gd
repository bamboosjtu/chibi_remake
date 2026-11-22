extends RefCounted
const ContextProjection = preload("res://app/read_models/context_projection.gd")
var _read_live: Callable
var _context_projection: ContextProjection

func _init(read_live: Callable, context_projection: ContextProjection) -> void:
	_read_live = read_live
	_context_projection = context_projection


func world_identity() -> int:
	var data: Object = _read_live.call()
	return data.world.get_instance_id() if data != null else -1

func clock_view() -> Dictionary:
	var data: Object = _read_live.call()
	return _context_projection.clock(data) if data != null else {}

func effect_views() -> Dictionary:
	var data: Object = _read_live.call()
	return _context_projection.effects(data) if data != null else {}

func event_count() -> int:
	var data: Object = _read_live.call()
	return data.task_events.size() if data != null else 0

func task_event_id(index: int) -> int:
	var data: Object = _read_live.call()
	if data == null: return -1
	return int(data.task_events[index].id) if index>=0 and index<data.task_events.size() else -1

func ai_level(owner: int) -> int:
	var data: Object = _read_live.call()
	return data.world.ai_economy.ai_level(owner) if data != null else 0

func tech_research_name() -> String:
	var data: Object = _read_live.call()
	return data.world.technology.tech_research_name() if data != null else ""

func tech_research_remaining() -> int:
	var data: Object = _read_live.call()
	return data.world.technology.tech_research_remaining() if data != null else 0
