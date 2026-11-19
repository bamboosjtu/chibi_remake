extends Node2D
## Explicit battle read model and command surface for presentation components.
## Data owner is weak and guarded. Scene/session and domain ports share subtree lifetime.
const Progression = preload("res://simulation/definitions/officer_grades.gd")
var _data: WeakRef
var _scene: RefCounted
var commands: RefCounted
var _unit_projection := preload("res://app/read_models/unit_projection.gd").new()
var _context_projection := preload("res://app/read_models/context_projection.gd").new()
var _resource_projection := preload("res://app/read_models/resource_projection.gd").new()

func _init(data: Object, services: RefCounted, commands: RefCounted) -> void:
	_data = weakref(data)
	_scene = services
	self.commands = commands

var cheat_input_open:
	get: return _scene.cheat_input_open

var cam:
	get: return _scene.cam

var cli_mode:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cli_mode if data != null else null

var cnt_enemy:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cnt_enemy if data != null else 0

var cnt_enemy_buildings:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cnt_enemy_buildings if data != null else 0

var cnt_player:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cnt_player if data != null else 0

func selection_description() -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
	if data == null: return {}
	var result: Dictionary = data.command_rules.describe().duplicate(true)
	result.make_read_only()
	return result

func selection_views() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"selection values")
	return _unit_projection.selection(data) if data != null else []

func unit_views() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"unit values")
	return _unit_projection.units(data) if data != null else []

func minimap_markers() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data, "minimap markers")
	return _unit_projection.minimap_markers(data) if data != null else []

func team_soldiers(owner: int, officer_index: int) -> int:
	var data = preload("res://named_port.gd").require_provider(_data, "team strength")
	return _unit_projection.team_soldiers(data, owner, officer_index) if data != null else 0

func commander_name(owner: int, officer_index: int) -> String:
	var data = preload("res://named_port.gd").require_provider(_data, "commander name")
	return _unit_projection.commander_name(data, owner, officer_index) if data != null else "—"

func renderable_unit_count() -> int:
	var data = preload("res://named_port.gd").require_provider(_data, "unit count")
	return data.units.size() if data != null else 0

func renderable_units(context: Dictionary) -> Array:
	var data = preload("res://named_port.gd").require_provider(_data, "visible unit values")
	return _unit_projection.renderable(data, context) if data != null else []

func world_identity() -> int:
	var data = preload("res://named_port.gd").require_provider(_data, "world identity")
	return data.world.get_instance_id() if data != null else -1

func roster_unit(uid: int) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data, "unit values")
	return _unit_projection.roster(data, uid) if data != null else {}

func visual_unit(uid: int) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"unit values")
	return _unit_projection.visual(data,uid) if data != null else {}

func motion_views(visible = null) -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"motion values")
	return _unit_projection.motion(data, visible) if data != null else []

func training_views() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"production values")
	return _unit_projection.training(data) if data != null else []

func building_work(uid: int) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"building work")
	return _unit_projection.work(data,uid) if data != null else {}

func officer_candidates() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"officer candidates")
	if data == null: return []
	var result: Array = data.commands.military.officers_for_selection(data.player_owner,data.selected).duplicate(true)
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

func unit_capacity(kind: int) -> float:
	var data = preload("res://named_port.gd").require_provider(_data,"unit capacity")
	return float(data.map_data.units.get(str(kind),{}).get("hp",1)) if data != null else 1.0

func map_caption() -> String:
	var data = preload("res://named_port.gd").require_provider(_data,"map caption")
	return str(data.map_data.get("name","")) if data != null else ""

func cell_anchor(a: int, b: int) -> Vector2:
	var data = preload("res://named_port.gd").require_provider(_data,"cell anchor")
	return data.nav.anchor_of(a,b) if data != null else Vector2.ZERO

func invalidate_unit_views() -> void:
	_unit_projection.invalidate()

func projection_counters() -> Dictionary:
	var result := _unit_projection.metrics.duplicate()
	result.merge(_context_projection.metrics)
	return result

func visibility_view() -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"visibility values")
	return _context_projection.visibility(data) if data != null else {}

func visibility_planes(key: Array) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data, "visibility planes")
	return _context_projection.visibility_planes(data,key) if data != null else {}

func visibility_geometry() -> Vector2:
	var data = preload("res://named_port.gd").require_provider(_data,"visibility geometry")
	return Vector2(data.visibility.width,data.visibility.height)*data.visibility.CELL if data != null else Vector2.ZERO

func point_visible(point: Vector2) -> bool:
	var data = preload("res://named_port.gd").require_provider(_data,"visibility query")
	return data.visibility.is_visible(point) if data != null else false

func clock_view() -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"clock values")
	return _context_projection.clock(data) if data != null else {}

func build_options() -> Array:
	var data = preload("res://named_port.gd").require_provider(_data,"build options")
	return _context_projection.options(data) if data != null else []

func effect_views() -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"effect values")
	return _context_projection.effects(data) if data != null else {}

func event_count() -> int:
	var data = preload("res://named_port.gd").require_provider(_data,"event count")
	return data.task_events.size() if data != null else 0

func task_event_id(index: int) -> int:
	var data = preload("res://named_port.gd").require_provider(_data,"event value")
	return int(data.task_events[index].id) if data != null and index>=0 and index<data.task_events.size() else -1

func terrain_has_changes(keys: Array) -> bool:
	var data = preload("res://named_port.gd").require_provider(_data,"terrain changes")
	return keys.all(func(key): return data.terrain_changes.has(key)) if data != null else false

func can_build_selected() -> bool:
	var data = preload("res://named_port.gd").require_provider(_data,"construction eligibility")
	return not data.commands.military._selected_construction_workers().is_empty() if data != null else false

func hover_view(point: Vector2) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"hover values")
	if data == null: return {}
	var hit: Dictionary = data.commands.orders._hover_unit(point)
	if hit.is_empty(): return preload("res://simulation/definitions/frozen_data.gd").copy({})
	return preload("res://simulation/definitions/frozen_data.gd").copy({"name":str(hit.name),"hp":float(hit.hp),"maxhp":float(hit.maxhp),"owner":int(hit.owner)})

func cursor_targets(point: Vector2, mode: String) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data,"cursor values")
	if data == null: return {}
	var result := {"hit":not data.commands.orders._hover_unit(point).is_empty(),"attack":false,"neutral":false,"neutral_allowed":false,"resource":false,"join":false}
	match mode:
		"attack":
			var target: Dictionary = data.commands.orders._attack_target_at(point)
			result.attack = not target.is_empty()
			result.neutral = not target.is_empty() and int(target.owner) == 0
			result.neutral_allowed = data.commands.orders._selected_has_nonworker_attacker()
		"transport": result.resource = not data.commands.economy._resource_at(point).is_empty() or not data.commands.economy._resource_at(point+Vector2(0,15)).is_empty()
		"join":
			var own: Dictionary = data.commands.orders._own_object_at(point)
			result.join = not own.is_empty() and not data.commands.military._commander_for(own).is_empty()
	result.make_read_only()
	return result

func camera_bounds() -> Vector2:
	var data = preload("res://named_port.gd").require_provider(_data, "camera bounds")
	return Vector2(float(data.map_data.get("terrainW",0)), float(data.map_data.get("terrainH",0))) if data != null else Vector2.ZERO

func opening_camera_position() -> Vector2:
	var data = preload("res://named_port.gd").require_provider(_data, "opening camera")
	if data == null: return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	var count := 0
	for unit in data.units:
		if int(unit.owner) == int(data.player_owner) and not bool(unit.is_building) and bool(unit.alive):
			x += float(unit.ax); y += float(unit.ay); count += 1
	return Vector2(x/count,y/count) if count > 0 else camera_bounds() * 0.5

func camera_tile_geometry() -> Vector3:
	var data = preload("res://named_port.gd").require_provider(_data, "camera tile geometry")
	return Vector3(float(data.tile_w),float(data.tile_hw),float(data.tile_hh)) if data != null else Vector3.ZERO

func construction_preview_key(point: Vector2) -> Array:
	var data = preload("res://named_port.gd").require_provider(_data, "construction preview")
	if data == null or commands.orders.cmd_pending_kind() != "build": return []
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
	result.make_read_only()
	return result

func construction_preview_at(point: Vector2) -> Dictionary:
	var data = preload("res://named_port.gd").require_provider(_data, "construction preview")
	if data == null or commands.orders.cmd_pending_kind() != "build": return {}
	var query: Dictionary = commands.economy.build_placement_at(point, data.cmd_pending_data)
	if query.is_empty(): return {}
	var meta: Dictionary = data.map_data.units.get(str(int(query.unit)), {})
	# Packed arrays remain mutable through a read-only Dictionary. Expose frozen value arrays.
	var result := {"valid":bool(query.valid),"unit":int(query.unit),"anchor":Vector2(query.anchor),
		"reason":str(query.reason),"cells":query.cells.duplicate(),"outline":Array(query.outline),
		"unit_size":Vector2(float(meta.get("w",0)),float(meta.get("h",0))),
		"sprite_k":float(meta.get("sheetK",data.map_data.get("spriteK",1)))}
	result["cell_polygons"] = _preview_cell_polygons(data.nav, result.cells)
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
	var data = preload("res://named_port.gd").require_provider(_data, "resource layer")
	if data == null: return []
	# Geometry, not blocker version: unrelated gates must not rescan static decor.
	var result := [data.world.get_instance_id(),data.nav.get_instance_id(),data.resource_revision,
		data.nav.geometry_revision,viewport]
	result.make_read_only()
	return result

func resource_layer_projection(viewport: Rect2) -> Array:
	var data = preload("res://named_port.gd").require_provider(_data, "resource layer")
	return _resource_projection.visible(data, viewport) if data != null else []

var ev_count:
	get: return _scene.ev_count

var feedback_text:
	get: return _scene.feedback_text

var food:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.food if data != null else 0

var game_end:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.game_end if data != null else null

var gold:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.gold if data != null else 0

var hover_text:
	get: return _scene.hover_text
	set(value): _scene.hover_text = value

var map_id:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.map_id if data != null else null

var officer_policy:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.officer_policy if data != null else null

var player_owner:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.player_owner if data != null else 0

var remaster_art:
	get: return _scene.remaster_art

var resource_revision:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.resource_revision if data != null else 0

var scenario_mission:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.scenario_mission if data != null else null

var scenario_source:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.scenario_source if data != null else null

var sec_visible:
	get: return _scene.sec_visible

var selecting:
	get: return _scene.selecting

var sfx:
	get: return _scene.sfx

var show_buildings:
	get: return _scene.show_buildings

var show_debug:
	get: return _scene.show_debug

var show_units:
	get: return _scene.show_units

var sim_tick:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.sim_tick if data != null else 0

var stone:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.stone if data != null else 0

var tile_hh:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.tile_hh if data != null else 0

var tile_hw:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.tile_hw if data != null else 0

var tile_w:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.tile_w if data != null else 0

var view:
	get: return _scene.view

var wood:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.wood if data != null else 0

func _exit_tree() -> void:
	_data = null

## Event playback uses this capability to distinguish a battle from the main menu.

## Capability marker for battle event playback.
func is_battle_context() -> bool:
	return true
