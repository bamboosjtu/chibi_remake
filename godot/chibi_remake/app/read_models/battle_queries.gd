extends RefCounted
## Battle queries expose scalar values and owned projections.
## The live reader belongs to the scene. A staging reader belongs to its candidate view.
var _data: Object
var _unit_projection := preload("res://app/read_models/unit_projection.gd").new()
var _context_projection := preload("res://app/read_models/context_projection.gd").new()
var _resource_projection := preload("res://app/read_models/resource_projection.gd").new()

func _init(data: Object) -> void:
	_data = data

var cli_mode:
	get:
		return _data.cli_mode

var cnt_enemy:
	get:
		return _data.cnt_enemy

var cnt_enemy_buildings:
	get:
		return _data.cnt_enemy_buildings

var cnt_player:
	get:
		return _data.cnt_player

func selection_description() -> Dictionary:

	var result: Dictionary = _data.command_rules.describe().duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func selection_views() -> Array:
	return _unit_projection.selection(_data)

func unit_views() -> Array:
	return _unit_projection.units(_data)

func minimap_markers() -> Array:
	return _unit_projection.minimap_markers(_data)

func team_soldiers(owner: int, officer_index: int) -> int:
	return _unit_projection.team_soldiers(_data, owner, officer_index)

func commander_name(owner: int, officer_index: int) -> String:
	return _unit_projection.commander_name(_data, owner, officer_index)

func renderable_unit_count() -> int:
	return _data.units.size()

func renderable_units(context: Dictionary) -> Array:
	return _unit_projection.renderable(_data, context)

func world_identity() -> int:
	return _data.world.get_instance_id()

func roster_unit(uid: int) -> Dictionary:
	return _unit_projection.roster(_data, uid)

func visual_unit(uid: int) -> Dictionary:
	return _unit_projection.visual(_data,uid)

func motion_views(visible = null) -> Array:
	return _unit_projection.motion(_data, visible)

func training_views() -> Array:
	return _unit_projection.training(_data)

func building_work(uid: int) -> Dictionary:
	return _unit_projection.work(_data,uid)

func officer_candidates() -> Array:

	var result: Array = _data.world.officer_pool.officers_for_selection(_data.player_owner,_data.selected).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func unit_capacity(kind: int) -> float:
	return float(_data.map_data.units.get(str(kind),{}).get("hp",1))

func map_caption() -> String:
	return str(_data.map_data.get("name",""))

func cell_anchor(a: int, b: int) -> Vector2:
	return _data.nav.anchor_of(a,b)

func invalidate_unit_views() -> void:
	_unit_projection.invalidate()

func projection_counters() -> Dictionary:
	var result := _unit_projection.metrics.duplicate()
	result.merge(_context_projection.metrics)
	return result

func visibility_view() -> Dictionary:
	return _context_projection.visibility(_data)

func visibility_planes(key: Array) -> Dictionary:
	return _context_projection.visibility_planes(_data,key)

func visibility_geometry() -> Vector2:
	return Vector2(_data.visibility.width,_data.visibility.height)*_data.visibility.CELL

func point_visible(point: Vector2) -> bool:
	return _data.visibility.is_visible(point)

func clock_view() -> Dictionary:
	return _context_projection.clock(_data)

func build_options() -> Array:
	return _context_projection.options(_data)

func effect_views() -> Dictionary:
	return _context_projection.effects(_data)

func event_count() -> int:
	return _data.task_events.size()

func task_event_id(index: int) -> int:
	return int(_data.task_events[index].id) if index>=0 and index<_data.task_events.size() else -1

func terrain_has_changes(keys: Array) -> bool:
	return keys.all(func(key): return _data.terrain_changes.has(key))

func can_build_selected() -> bool:
	return not _data.world.command_groups._selected_construction_workers().is_empty()

func hover_view(point: Vector2) -> Dictionary:

	var hit: Dictionary = _data.world.selection._hover_unit(point)
	if hit.is_empty(): return preload("res://simulation/definitions/frozen_data.gd").copy({})
	return preload("res://simulation/definitions/frozen_data.gd").copy({"name":str(hit.name),"hp":float(hit.hp),"maxhp":float(hit.maxhp),"owner":int(hit.owner)})

func cursor_targets(point: Vector2, mode: String) -> Dictionary:

	var result := {"hit":not _data.world.selection._hover_unit(point).is_empty(),"attack":false,"neutral":false,"neutral_allowed":false,"resource":false,"join":false}
	match mode:
		"attack":
			var target: Dictionary = _data.world.selection._attack_target_at(point)
			result.attack = not target.is_empty()
			result.neutral = not target.is_empty() and int(target.owner) == 0
			result.neutral_allowed = _data.world.world_orders._selected_has_nonworker_attacker()
		"transport": result.resource = not _data.world.harvest_orders._resource_at(point).is_empty() or not _data.world.harvest_orders._resource_at(point+Vector2(0,15)).is_empty()
		"join":
			var own: Dictionary = _data.world.selection._own_object_at(point)
			result.join = not own.is_empty() and not _data.world.command_groups._commander_for(own).is_empty()
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func camera_bounds() -> Vector2:
	return Vector2(float(_data.map_data.get("terrainW",0)), float(_data.map_data.get("terrainH",0)))

func opening_camera_position() -> Vector2:

	var x := 0.0
	var y := 0.0
	var count := 0
	for unit in _data.units:
		if int(unit.owner) == int(_data.player_owner) and not bool(unit.is_building) and bool(unit.alive):
			x += float(unit.ax); y += float(unit.ay); count += 1
	return Vector2(x/count,y/count) if count > 0 else camera_bounds() * 0.5

func camera_tile_geometry() -> Vector3:
	return Vector3(float(_data.tile_w),float(_data.tile_hw),float(_data.tile_hh))

func construction_preview_key(point: Vector2) -> Array:
	if _data.world.world_orders.cmd_pending_kind() != "build": return []
	var bid := int(_data.cmd_pending_data.get("unit", -1))
	var meta: Dictionary = _data.map_data.units.get(str(bid), {})
	var selected := []
	for unit in _data.selected: selected.append(int(unit.uid))
	selected.make_read_only()
	# Values only. A replacement world can have identical ticks, UIDs and nav versions.
	var result := [_data.world.get_instance_id(), _data.nav.get_instance_id(), bid,
		_data.nav.cell_of_px(point.x,point.y), _data.sim_tick, _data.nav.version, _data.units.size(), selected,
		_data.gold, _data.wood, _data.food, _data.stone, _data.game_end, _data.player_owner, _data.cheat_build_any,
		meta.get("w",0), meta.get("h",0), meta.get("sheetK",_data.map_data.get("spriteK",1))]
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func construction_preview_at(point: Vector2) -> Dictionary:
	if _data.world.world_orders.cmd_pending_kind() != "build": return {}
	var query: Dictionary = _data.world.construction_orders.build_placement_at(point, _data.cmd_pending_data)
	if query.is_empty(): return {}
	var meta: Dictionary = _data.map_data.units.get(str(int(query.unit)), {})
	# Packed arrays remain mutable through a read-only Dictionary. Expose frozen value arrays.
	var result := {"valid":bool(query.valid),"unit":int(query.unit),"anchor":Vector2(query.anchor),
		"reason":str(query.reason),"cells":query.cells.duplicate(),"outline":Array(query.outline),
		"unit_size":Vector2(float(meta.get("w",0)),float(meta.get("h",0))),
		"sprite_k":float(meta.get("sheetK",_data.map_data.get("spriteK",1)))}
	result["cell_polygons"] = _preview_cell_polygons(_data.nav, result.cells)
	# Whitelist bounded values and freeze owned containers; no deep copy of domain records.
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func _preview_cell_polygons(navigation: Object, cells: Array) -> Array:
	var result := []
	var hw: float = navigation.tile_hw
	var hh: float = navigation.tile_hh
	for cell in cells:
		var point: Vector2 = navigation.anchor_of(cell.x,cell.y)
		var corners := [point+Vector2(0,-hh),point+Vector2(hw,0),point+Vector2(0,hh),point+Vector2(-hw,0)]
		corners.append(corners[0])
		result.append(corners)
	return result

func resource_layer_key(viewport: Rect2) -> Array:

	# Geometry, not blocker version: unrelated gates must not rescan static decor.
	var result := [_data.world.get_instance_id(),_data.nav.get_instance_id(),_data.resource_revision,
		_data.nav.geometry_revision,viewport]
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func resource_layer_projection(viewport: Rect2) -> Array:
	return _resource_projection.visible(_data, viewport)

var food:
	get:
		return _data.food

var game_end:
	get:
		return _data.game_end

var gold:
	get:
		return _data.gold

var map_id:
	get:
		return _data.map_id

var officer_policy:
	get:
		return _data.officer_policy

var player_owner:
	get:
		return _data.player_owner

var resource_revision:
	get:
		return _data.resource_revision

var scenario_mission:
	get:
		return _data.scenario_mission

var scenario_source:
	get:
		return _data.scenario_source

var sim_tick:
	get:
		return _data.sim_tick

var stone:
	get:
		return _data.stone

var tile_hh:
	get:
		return _data.tile_hh

var tile_hw:
	get:
		return _data.tile_hw

var tile_w:
	get:
		return _data.tile_w

var wood:
	get:
		return _data.wood

func officer_rank_name(off: Dictionary) -> String:
	return _data.world.combat.officer_rank_name(off)

func ai_level(owner: int) -> int:
	return _data.world.ai_economy.ai_level(owner)

func tech_is_sell(idx: int) -> bool:
	return _data.world.technology.tech_is_sell(idx)

func tech_row(idx: int) -> Dictionary:
	var result = _data.world.technology.tech_row(idx).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func cmd_pending_kind() -> String:
	return _data.world.world_orders.cmd_pending_kind()

func train_types_for(bid: int, owner: int = -1) -> Array:
	var result = _data.world.production.train_types_for(bid, owner).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func building_block_reason(bid: int, owner: int = -1) -> String:
	return _data.world.construction_orders.building_block_reason(bid, owner)

func control_group_summaries() -> Array:
	var result = _data.world.command_groups.control_group_summaries().duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func tech_research_active() -> bool:
	return _data.world.technology.tech_research_active()

func tech_rows_for_building(bid: int) -> Array:
	var result = _data.world.technology.tech_rows_for_building(bid).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func tech_is_next(idx: int) -> bool:
	return _data.world.technology.tech_is_next(idx)

func tech_unlocked(idx: int) -> bool:
	return _data.world.technology.tech_unlocked(idx)

func tech_cost(idx: int) -> Dictionary:
	var result = _data.world.technology.tech_cost(idx).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func tech_effect_desc(idx: int) -> String:
	return _data.world.technology.tech_effect_desc(idx)

func tech_tip(idx: int) -> String:
	return _data.world.technology.tech_tip(idx)

func tech_block_reason(idx: int) -> String:
	return _data.world.technology.tech_block_reason(idx)

func tech_cost_text(idx: int) -> String:
	return _data.world.technology.tech_cost_text(idx)

func tech_research_name() -> String:
	return _data.world.technology.tech_research_name()

func tech_research_remaining() -> int:
	return _data.world.technology.tech_research_remaining()

func sheet_ref_for(unit_id: int, owner: int) -> String:
	return _data.world.entity_factory._sheet_ref_for(unit_id, owner)

func unit_name(unit_id: int) -> String:
	return _data.world.campaign._unit_name(unit_id)

func cell_of_px(px: float, py: float) -> Vector2i:
	return _data.world.movement._cell_of_px(px, py)
