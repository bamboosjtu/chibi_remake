extends RefCounted
const UnitProjection = preload("res://app/read_models/unit_projection.gd")
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
var _read_live: Callable
var _unit_projection: UnitProjection

func _init(read_live: Callable, unit_projection: UnitProjection) -> void:
	_read_live = read_live
	_unit_projection = unit_projection


func selection_views() -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.selection(data) if data != null else []

func unit_views() -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.units(data) if data != null else []

func minimap_markers() -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.minimap_markers(data) if data != null else []

func team_soldiers(owner: int, officer_index: int) -> int:
	var data: Object = _read_live.call()
	return _unit_projection.team_soldiers(data, owner, officer_index) if data != null else 0

func commander_name(owner: int, officer_index: int) -> String:
	var data: Object = _read_live.call()
	return _unit_projection.commander_name(data, owner, officer_index) if data != null else "—"

func renderable_unit_count() -> int:
	var data: Object = _read_live.call()
	return data.units.size() if data != null else 0

func renderable_units(context: Dictionary) -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.renderable(data, context) if data != null else []

func roster_unit(uid: int) -> Dictionary:
	var data: Object = _read_live.call()
	return _unit_projection.roster(data, uid) if data != null else {}

func visual_unit(uid: int) -> Dictionary:
	var data: Object = _read_live.call()
	return _unit_projection.visual(data,uid) if data != null else {}

func motion_views(visible = null) -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.motion(data, visible) if data != null else []

func training_views() -> Array:
	var data: Object = _read_live.call()
	return _unit_projection.training(data) if data != null else []

func building_work(uid: int) -> Dictionary:
	var data: Object = _read_live.call()
	return _unit_projection.work(data,uid) if data != null else {}

func officer_candidates() -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	var result: Array = data.world.officer_pool.officers_for_selection(data.player_owner,data.selected).duplicate(true)
	Frozen.freeze(result)
	return result

func unit_capacity(kind: int) -> float:
	var data: Object = _read_live.call()
	return float(data.map_data.units.get(str(kind),{}).get("hp",1)) if data != null else 1.0

func invalidate_unit_views() -> void:
	_unit_projection.invalidate()

func hover_view(point: Vector2) -> Dictionary:
	var data: Object = _read_live.call()
	if data == null: return Frozen.copy({})
	var hit: Dictionary = data.world.selection._hover_unit(point)
	if hit.is_empty(): return Frozen.copy({})
	return Frozen.copy({"name":str(hit.name),"hp":float(hit.hp),"maxhp":float(hit.maxhp),"owner":int(hit.owner)})

func sheet_ref_for(unit_id: int, owner: int) -> String:
	var data: Object = _read_live.call()
	return data.world.entity_factory._sheet_ref_for(unit_id, owner) if data != null else ""

func unit_name(unit_id: int) -> String:
	var data: Object = _read_live.call()
	return data.world.campaign._unit_name(unit_id) if data != null else ""

func officer_rank_name(off: Dictionary) -> String:
	var data: Object = _read_live.call()
	return data.world.combat.officer_rank_name(off) if data != null else ""
