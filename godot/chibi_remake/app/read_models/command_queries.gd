extends RefCounted
const ContextProjection = preload("res://app/read_models/context_projection.gd")
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
var _read_live: Callable
var _context_projection: ContextProjection

func _init(read_live: Callable, context_projection: ContextProjection) -> void:
	_read_live = read_live
	_context_projection = context_projection


func selection_description() -> Dictionary:
	var data: Object = _read_live.call()
	if data == null: return {}
	var result: Dictionary = data.command_rules.describe().duplicate(true)
	Frozen.freeze(result)
	return result

func build_options() -> Array:
	var data: Object = _read_live.call()
	return _context_projection.options(data) if data != null else []

func can_build_selected() -> bool:
	var data: Object = _read_live.call()
	return not data.world.command_groups._selected_construction_workers().is_empty() if data != null else false

func cursor_targets(point: Vector2, mode: String) -> Dictionary:
	var result := {"hit":false,"attack":false,"neutral":false,"neutral_allowed":false,"resource":false,"join":false}
	var data: Object = _read_live.call()
	if data == null:
		Frozen.freeze(result)
		return result
	result.hit = not data.world.selection._hover_unit(point).is_empty()
	match mode:
		"attack":
			var target: Dictionary = data.world.selection._attack_target_at(point)
			result.attack = not target.is_empty()
			result.neutral = not target.is_empty() and int(target.owner) == 0
			result.neutral_allowed = data.world.world_orders._selected_has_nonworker_attacker()
		"transport": result.resource = not data.world.harvest_orders._resource_at(point).is_empty() or not data.world.harvest_orders._resource_at(point+Vector2(0,15)).is_empty()
		"join":
			var own: Dictionary = data.world.selection._own_object_at(point)
			result.join = not own.is_empty() and not data.world.command_groups._commander_for(own).is_empty()
	Frozen.freeze(result)
	return result

func tech_is_sell(idx: int) -> bool:
	var data: Object = _read_live.call()
	return data.world.technology.tech_is_sell(idx) if data != null else false

func tech_row(idx: int) -> Dictionary:
	var data: Object = _read_live.call()
	if data == null: return {}
	var result = data.world.technology.tech_row(idx).duplicate(true)
	Frozen.freeze(result)
	return result

func cmd_pending_kind() -> String:
	var data: Object = _read_live.call()
	return data.world.world_orders.cmd_pending_kind() if data != null else ""

func train_types_for(bid: int, owner: int = -1) -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	var result = data.world.production.train_types_for(bid, owner).duplicate(true)
	Frozen.freeze(result)
	return result

func building_block_reason(bid: int, owner: int = -1) -> String:
	var data: Object = _read_live.call()
	return data.world.construction_orders.building_block_reason(bid, owner) if data != null else ""

func control_group_summaries() -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	var result = data.world.command_groups.control_group_summaries().duplicate(true)
	Frozen.freeze(result)
	return result

func tech_research_active() -> bool:
	var data: Object = _read_live.call()
	return data.world.technology.tech_research_active() if data != null else false

func tech_rows_for_building(bid: int) -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	var result = data.world.technology.tech_rows_for_building(bid).duplicate(true)
	Frozen.freeze(result)
	return result

func tech_is_next(idx: int) -> bool:
	var data: Object = _read_live.call()
	return data.world.technology.tech_is_next(idx) if data != null else false

func tech_unlocked(idx: int) -> bool:
	var data: Object = _read_live.call()
	return data.world.technology.tech_unlocked(idx) if data != null else false

func tech_cost(idx: int) -> Dictionary:
	var data: Object = _read_live.call()
	if data == null: return {}
	var result = data.world.technology.tech_cost(idx).duplicate(true)
	Frozen.freeze(result)
	return result

func tech_effect_desc(idx: int) -> String:
	var data: Object = _read_live.call()
	return data.world.technology.tech_effect_desc(idx) if data != null else ""

func tech_tip(idx: int) -> String:
	var data: Object = _read_live.call()
	return data.world.technology.tech_tip(idx) if data != null else ""

func tech_block_reason(idx: int) -> String:
	var data: Object = _read_live.call()
	return data.world.technology.tech_block_reason(idx) if data != null else ""

func tech_cost_text(idx: int) -> String:
	var data: Object = _read_live.call()
	return data.world.technology.tech_cost_text(idx) if data != null else ""
