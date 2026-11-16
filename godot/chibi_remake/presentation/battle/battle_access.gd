extends Node2D
## Explicit battle read model and command surface for presentation components.
## Data owner is weak and guarded. Scene/session and domain ports share subtree lifetime.
const Config = preload("res://simulation/battle_config.gd")
const ActionClock = preload("res://simulation/definitions/action_visual.gd")
const EXP_LEVELS = Config.EXP_LEVELS
const Progression = preload("res://simulation/definitions/officer_grades.gd")
const TECH_TICKS = Config.TECH_TICKS
var _data: WeakRef
var _scene: RefCounted
var commands: RefCounted

func _init(data: Object, services: RefCounted, commands: RefCounted) -> void:
	_data = weakref(data)
	_scene = services
	self.commands = commands

var cheat_input_open:
	get: return _scene.cheat_input_open

var build_types:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.build_types if data != null else null

var cam:
	get: return _scene.cam

var cli_mode:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cli_mode if data != null else null

var clock:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.clock if data != null else null

var cmd_pending_data:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.cmd_pending_data if data != null else null

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
	if data == null: return []
	var result := []
	var decor: Array = data.map_data.get("decor", [])
	for index in range(decor.size()):
		var cell: Array = decor[index]
		var anchor: Vector2 = data.nav.anchor_of(int(cell[0]),int(cell[1]))
		if not viewport.intersects(Rect2(anchor-Vector2(22,60),Vector2(44,60))): continue
		var source: Dictionary = data.decor_cells.get("%d_%d" % [int(cell[0]),int(cell[1])], {})
		result.append({"index":index,"anchor":anchor,"phase":int(source.get("phase",cell[2]))})
	# Only visible scalar/vector descriptors; no retained decor, source dictionary or nav.
	preload("res://simulation/definitions/frozen_data.gd").freeze(result)
	return result

var ev_count:
	get: return _scene.ev_count

var feedback_text:
	get: return _scene.feedback_text

var fire_fields:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.fire_fields if data != null else null

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

var map_data:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.map_data if data != null else null

var map_id:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.map_id if data != null else null

var nav:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.nav if data != null else null

var officer_policy:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.officer_policy if data != null else null

var player_commands:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.player_commands if data != null else null

var player_owner:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.player_owner if data != null else 0

var projectiles:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.projectiles if data != null else null

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

var selected:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.selected if data != null else null

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

var task_events:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.task_events if data != null else null

var terrain_changes:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.terrain_changes if data != null else null

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

var trainings:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.trainings if data != null else null

var units:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.units if data != null else null

var view:
	get: return _scene.view

var visibility:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.visibility if data != null else null

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
