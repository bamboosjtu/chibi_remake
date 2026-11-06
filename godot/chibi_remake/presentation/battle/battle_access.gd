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

var decor_cells:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.decor_cells if data != null else null

var ev_count:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.ev_count if data != null else 0

var feedback_text:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.feedback_text if data != null else null

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

var saver:
	get: return _scene.saver

var scenario_mission:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.scenario_mission if data != null else null

var scenario_source:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.scenario_source if data != null else null

var sec_visible:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.sec_visible if data != null else null

var selected:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.selected if data != null else null

var selecting:
	get:
		var data = preload("res://named_port.gd").require_provider(_data, "battle read model")
		return data.selecting if data != null else null

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
