extends RefCounted
## Battle queries expose scalar values and owned projections.
## The live reader belongs to the scene. A staging reader belongs to its candidate view.
## The host is held weakly: after it is released every query returns the empty value of
## its own type and the contract reports the failure, so teardown can never dereference a
## freed node. Read models must stay usable after `queue_free` of their host.
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
const Contract = preload("res://composition_contract.gd")
var _data: WeakRef
var _reported := false
var _unit_projection := preload("res://app/read_models/unit_projection.gd").new()
var _context_projection := preload("res://app/read_models/context_projection.gd").new()
var _resource_projection := preload("res://app/read_models/resource_projection.gd").new()

func _init(data: Object) -> void:
	_data = weakref(data)

## Returns the live host, or null once it has been released. The first expiry reports a
## contract failure (exit 1) and every later query returns its empty value silently.
func _live() -> Object:
	var data: Object = _data.get_ref() if _data != null else null
	if data == null and not _reported:
		_reported = true
		Contract.abort_if_broken("battle read model", [{"provider": "battle read model", "method": "provider lifetime"}])
	return data

var cli_mode:
	get:
		var data := _live()
		return data.cli_mode if data != null else null

var cnt_enemy:
	get:
		var data := _live()
		return data.cnt_enemy if data != null else 0

var cnt_enemy_buildings:
	get:
		var data := _live()
		return data.cnt_enemy_buildings if data != null else 0

var cnt_player:
	get:
		var data := _live()
		return data.cnt_player if data != null else 0

func selection_description() -> Dictionary:
	var data := _live()
	if data == null: return {}
	var result: Dictionary = data.command_rules.describe().duplicate(true)
	Frozen.freeze(result)
	return result

func selection_views() -> Array:
	var data := _live()
	return _unit_projection.selection(data) if data != null else []

func unit_views() -> Array:
	var data := _live()
	return _unit_projection.units(data) if data != null else []

func minimap_markers() -> Array:
	var data := _live()
	return _unit_projection.minimap_markers(data) if data != null else []

func team_soldiers(owner: int, officer_index: int) -> int:
	var data := _live()
	return _unit_projection.team_soldiers(data, owner, officer_index) if data != null else 0

func commander_name(owner: int, officer_index: int) -> String:
	var data := _live()
	return _unit_projection.commander_name(data, owner, officer_index) if data != null else "—"

func renderable_unit_count() -> int:
	var data := _live()
	return data.units.size() if data != null else 0

func renderable_units(context: Dictionary) -> Array:
	var data := _live()
	return _unit_projection.renderable(data, context) if data != null else []

func world_identity() -> int:
	var data := _live()
	return data.world.get_instance_id() if data != null else -1

func roster_unit(uid: int) -> Dictionary:
	var data := _live()
	return _unit_projection.roster(data, uid) if data != null else {}

func visual_unit(uid: int) -> Dictionary:
	var data := _live()
	return _unit_projection.visual(data,uid) if data != null else {}

func motion_views(visible = null) -> Array:
	var data := _live()
	return _unit_projection.motion(data, visible) if data != null else []

func training_views() -> Array:
	var data := _live()
	return _unit_projection.training(data) if data != null else []

func building_work(uid: int) -> Dictionary:
	var data := _live()
	return _unit_projection.work(data,uid) if data != null else {}

func officer_candidates() -> Array:
	var data := _live()
	if data == null: return []
	var result: Array = data.world.officer_pool.officers_for_selection(data.player_owner,data.selected).duplicate(true)
	Frozen.freeze(result)
	return result

func unit_capacity(kind: int) -> float:
	var data := _live()
	return float(data.map_data.units.get(str(kind),{}).get("hp",1)) if data != null else 1.0

func map_caption() -> String:
	var data := _live()
	return str(data.map_data.get("name","")) if data != null else ""

func invalidate_unit_views() -> void:
	_unit_projection.invalidate()

func projection_counters() -> Dictionary:
	var result := _unit_projection.metrics.duplicate()
	result.merge(_context_projection.metrics)
	return result

func visibility_view() -> Dictionary:
	var data := _live()
	return _context_projection.visibility(data) if data != null else {}

func visibility_planes(key: Array) -> Dictionary:
	var data := _live()
	return _context_projection.visibility_planes(data,key) if data != null else {}

func visibility_geometry() -> Vector2:
	var data := _live()
	if data == null: return Vector2.ZERO
	return Vector2(data.visibility.width,data.visibility.height)*data.visibility.CELL

func point_visible(point: Vector2) -> bool:
	var data := _live()
	return data.visibility.is_visible(point) if data != null else false

func clock_view() -> Dictionary:
	var data := _live()
	return _context_projection.clock(data) if data != null else {}

func build_options() -> Array:
	var data := _live()
	return _context_projection.options(data) if data != null else []

func effect_views() -> Dictionary:
	var data := _live()
	return _context_projection.effects(data) if data != null else {}

func event_count() -> int:
	var data := _live()
	return data.task_events.size() if data != null else 0

func task_event_id(index: int) -> int:
	var data := _live()
	if data == null: return -1
	return int(data.task_events[index].id) if index>=0 and index<data.task_events.size() else -1

func terrain_has_changes(keys: Array) -> bool:
	var data := _live()
	return keys.all(func(key): return data.terrain_changes.has(key)) if data != null else false

func can_build_selected() -> bool:
	var data := _live()
	return not data.world.command_groups._selected_construction_workers().is_empty() if data != null else false

func hover_view(point: Vector2) -> Dictionary:
	var data := _live()
	if data == null: return Frozen.copy({})
	var hit: Dictionary = data.world.selection._hover_unit(point)
	if hit.is_empty(): return Frozen.copy({})
	return Frozen.copy({"name":str(hit.name),"hp":float(hit.hp),"maxhp":float(hit.maxhp),"owner":int(hit.owner)})

func cursor_targets(point: Vector2, mode: String) -> Dictionary:
	var result := {"hit":false,"attack":false,"neutral":false,"neutral_allowed":false,"resource":false,"join":false}
	var data := _live()
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

func camera_bounds() -> Vector2:
	var data := _live()
	return Vector2(float(data.map_data.get("terrainW",0)), float(data.map_data.get("terrainH",0))) if data != null else Vector2.ZERO

func opening_camera_position() -> Vector2:
	var data := _live()
	if data == null: return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	var count := 0
	for unit in data.units:
		if int(unit.owner) == int(data.player_owner) and not bool(unit.is_building) and bool(unit.alive):
			x += float(unit.ax); y += float(unit.ay); count += 1
	return Vector2(x/count,y/count) if count > 0 else camera_bounds() * 0.5

func camera_tile_geometry() -> Vector3:
	var data := _live()
	return Vector3(float(data.tile_w),float(data.tile_hw),float(data.tile_hh)) if data != null else Vector3.ZERO

func construction_preview_key(point: Vector2) -> Array:
	var data := _live()
	if data == null: return []
	if data.world.world_orders.cmd_pending_kind() != "build": return []
	var bid := int(data.cmd_pending_data.get("unit", -1))
	var meta: Dictionary = data.map_data.units.get(str(bid), {})
	var selected := []
	for unit in data.selected: selected.append(int(unit.uid))
	selected.make_read_only()
	# Values only. A replacement world can have identical ticks, UIDs and nav versions.
	var result := [data.world.get_instance_id(), data.nav.get_instance_id(), bid,
		data.nav.cell_of_px(point.x,point.y), data.sim_tick, data.nav.version, data.units.size(), selected,
		data.gold, data.wood, data.food, data.stone, data.game_end, data.player_owner, data.cheat_build_any,
		meta.get("w",0), meta.get("h",0), meta.get("sheetK",data.map_data.get("spriteK",1))]
	Frozen.freeze(result)
	return result

func construction_preview_at(point: Vector2) -> Dictionary:
	var data := _live()
	if data == null: return {}
	if data.world.world_orders.cmd_pending_kind() != "build": return {}
	var query: Dictionary = data.world.construction_orders.build_placement_at(point, data.cmd_pending_data)
	if query.is_empty(): return {}
	var meta: Dictionary = data.map_data.units.get(str(int(query.unit)), {})
	# Packed arrays remain mutable through a read-only Dictionary. Expose frozen value arrays.
	var result := {"valid":bool(query.valid),"unit":int(query.unit),"anchor":Vector2(query.anchor),
		"reason":str(query.reason),"cells":query.cells.duplicate(),"outline":Array(query.outline),
		"unit_size":Vector2(float(meta.get("w",0)),float(meta.get("h",0))),
		"sprite_k":float(meta.get("sheetK",data.map_data.get("spriteK",1)))}
	result["cell_polygons"] = _preview_cell_polygons(data.nav, result.cells)
	# Whitelist bounded values and freeze owned containers; no deep copy of domain records.
	Frozen.freeze(result)
	return result

func _preview_cell_polygons(navigation: Object, cells: Array) -> Array:
	var result := []
	if navigation == null: return result
	var hw: float = navigation.tile_hw
	var hh: float = navigation.tile_hh
	for cell in cells:
		var point: Vector2 = navigation.anchor_of(cell.x,cell.y)
		var corners := [point+Vector2(0,-hh),point+Vector2(hw,0),point+Vector2(0,hh),point+Vector2(-hw,0)]
		corners.append(corners[0])
		result.append(corners)
	return result

func resource_layer_key(viewport: Rect2) -> Array:
	var data := _live()
	if data == null: return []
	# Geometry, not blocker version: unrelated gates must not rescan static decor.
	var result := [data.world.get_instance_id(),data.nav.get_instance_id(),data.resource_revision,
		data.nav.geometry_revision,viewport]
	Frozen.freeze(result)
	return result

func resource_layer_projection(viewport: Rect2) -> Array:
	var data := _live()
	return _resource_projection.visible(data, viewport) if data != null else []

var food:
	get:
		var data := _live()
		return data.food if data != null else 0.0

var game_end:
	get:
		var data := _live()
		return data.game_end if data != null else 0

var gold:
	get:
		var data := _live()
		return data.gold if data != null else 0.0

var map_id:
	get:
		var data := _live()
		return data.map_id if data != null else ""

var officer_policy:
	get:
		var data := _live()
		return data.officer_policy if data != null else ""

var player_owner:
	get:
		var data := _live()
		return data.player_owner if data != null else 0

var resource_revision:
	get:
		var data := _live()
		return data.resource_revision if data != null else 0

var scenario_mission:
	get:
		var data := _live()
		return data.scenario_mission if data != null else -1

var scenario_source:
	get:
		var data := _live()
		return data.scenario_source if data != null else ""

var sim_tick:
	get:
		var data := _live()
		return data.sim_tick if data != null else 0

var stone:
	get:
		var data := _live()
		return data.stone if data != null else 0.0

var tile_hh:
	get:
		var data := _live()
		return data.tile_hh if data != null else 0.0

var tile_hw:
	get:
		var data := _live()
		return data.tile_hw if data != null else 0.0

var tile_w:
	get:
		var data := _live()
		return data.tile_w if data != null else 0.0

var wood:
	get:
		var data := _live()
		return data.wood if data != null else 0.0

func officer_rank_name(off: Dictionary) -> String:
	var data := _live()
	return data.world.combat.officer_rank_name(off) if data != null else ""

func ai_level(owner: int) -> int:
	var data := _live()
	return data.world.ai_economy.ai_level(owner) if data != null else 0

func tech_is_sell(idx: int) -> bool:
	var data := _live()
	return data.world.technology.tech_is_sell(idx) if data != null else false

func tech_row(idx: int) -> Dictionary:
	var data := _live()
	if data == null: return {}
	var result = data.world.technology.tech_row(idx).duplicate(true)
	Frozen.freeze(result)
	return result

func cmd_pending_kind() -> String:
	var data := _live()
	return data.world.world_orders.cmd_pending_kind() if data != null else ""

func train_types_for(bid: int, owner: int = -1) -> Array:
	var data := _live()
	if data == null: return []
	var result = data.world.production.train_types_for(bid, owner).duplicate(true)
	Frozen.freeze(result)
	return result

func building_block_reason(bid: int, owner: int = -1) -> String:
	var data := _live()
	return data.world.construction_orders.building_block_reason(bid, owner) if data != null else ""

func control_group_summaries() -> Array:
	var data := _live()
	if data == null: return []
	var result = data.world.command_groups.control_group_summaries().duplicate(true)
	Frozen.freeze(result)
	return result

func tech_research_active() -> bool:
	var data := _live()
	return data.world.technology.tech_research_active() if data != null else false

func tech_rows_for_building(bid: int) -> Array:
	var data := _live()
	if data == null: return []
	var result = data.world.technology.tech_rows_for_building(bid).duplicate(true)
	Frozen.freeze(result)
	return result

func tech_is_next(idx: int) -> bool:
	var data := _live()
	return data.world.technology.tech_is_next(idx) if data != null else false

func tech_unlocked(idx: int) -> bool:
	var data := _live()
	return data.world.technology.tech_unlocked(idx) if data != null else false

func tech_cost(idx: int) -> Dictionary:
	var data := _live()
	if data == null: return {}
	var result = data.world.technology.tech_cost(idx).duplicate(true)
	Frozen.freeze(result)
	return result

func tech_effect_desc(idx: int) -> String:
	var data := _live()
	return data.world.technology.tech_effect_desc(idx) if data != null else ""

func tech_tip(idx: int) -> String:
	var data := _live()
	return data.world.technology.tech_tip(idx) if data != null else ""

func tech_block_reason(idx: int) -> String:
	var data := _live()
	return data.world.technology.tech_block_reason(idx) if data != null else ""

func tech_cost_text(idx: int) -> String:
	var data := _live()
	return data.world.technology.tech_cost_text(idx) if data != null else ""

func tech_research_name() -> String:
	var data := _live()
	return data.world.technology.tech_research_name() if data != null else ""

func tech_research_remaining() -> int:
	var data := _live()
	return data.world.technology.tech_research_remaining() if data != null else 0

func sheet_ref_for(unit_id: int, owner: int) -> String:
	var data := _live()
	return data.world.entity_factory._sheet_ref_for(unit_id, owner) if data != null else ""

func unit_name(unit_id: int) -> String:
	var data := _live()
	return data.world.campaign._unit_name(unit_id) if data != null else ""

func cell_of_px(px: float, py: float) -> Vector2i:
	var data := _live()
	return data.world.movement._cell_of_px(px, py) if data != null else Vector2i(-1, -1)
