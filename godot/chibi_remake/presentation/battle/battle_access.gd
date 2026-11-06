extends Node2D
## Explicit battle read model and command surface for presentation components.
## The facade retains no battle scene reference; state is queried through weak owners.
const Config = preload("res://simulation/battle_config.gd")
const ActionClock = preload("res://simulation/definitions/action_visual.gd")
const EXP_LEVELS = Config.EXP_LEVELS
const Progression = preload("res://simulation/definitions/officer_grades.gd")
const TECH_TICKS = Config.TECH_TICKS
var _data: WeakRef
var _scene: WeakRef
var _commands: WeakRef
var commands: RefCounted:
	get: return _commands.get_ref()

func _init(data: Object, services: RefCounted, commands: RefCounted) -> void:
	_data = weakref(data)
	_scene = weakref(services)
	_commands = weakref(commands)

var cheat_input_open:
	get: return _scene.get_ref().cheat_input_open

func handle_cheat_input(event: InputEvent) -> bool:
	return _commands.get_ref().handle_cheat_input(event)

var build_types:
	get: return _data.get_ref().build_types

var cam:
	get: return _scene.get_ref().cam

var cli_mode:
	get: return _data.get_ref().cli_mode

var clock:
	get: return _data.get_ref().clock

var cmd_pending_data:
	get: return _data.get_ref().cmd_pending_data

var cnt_enemy:
	get: return _data.get_ref().cnt_enemy

var cnt_enemy_buildings:
	get: return _data.get_ref().cnt_enemy_buildings

var cnt_player:
	get: return _data.get_ref().cnt_player

func selection_description() -> Dictionary:
	var result: Dictionary = _data.get_ref().command_rules.describe().duplicate(true)
	result.make_read_only()
	return result

var decor_cells:
	get: return _data.get_ref().decor_cells

var ev_count:
	get: return _data.get_ref().ev_count

var feedback_text:
	get: return _data.get_ref().feedback_text

var fire_fields:
	get: return _data.get_ref().fire_fields

var food:
	get: return _data.get_ref().food

var game_end:
	get: return _data.get_ref().game_end

var gold:
	get: return _data.get_ref().gold

var hover_text:
	get: return _scene.get_ref().hover_text
	set(value): _scene.get_ref().hover_text = value

var map_data:
	get: return _data.get_ref().map_data

var map_id:
	get: return _data.get_ref().map_id

var nav:
	get: return _data.get_ref().nav

var officer_policy:
	get: return _data.get_ref().officer_policy

var player_commands:
	get: return _data.get_ref().player_commands

var player_owner:
	get: return _data.get_ref().player_owner

var projectiles:
	get: return _data.get_ref().projectiles

var remaster_art:
	get: return _scene.get_ref().remaster_art

var resource_revision:
	get: return _data.get_ref().resource_revision

var saver:
	get: return _scene.get_ref().saver

var scenario_mission:
	get: return _data.get_ref().scenario_mission

var scenario_source:
	get: return _data.get_ref().scenario_source

var sec_visible:
	get: return _data.get_ref().sec_visible

var selected:
	get: return _data.get_ref().selected

var selecting:
	get: return _data.get_ref().selecting

var sfx:
	get: return _scene.get_ref().sfx

var show_buildings:
	get: return _scene.get_ref().show_buildings

var show_debug:
	get: return _scene.get_ref().show_debug

var show_units:
	get: return _scene.get_ref().show_units

var sim_tick:
	get: return _data.get_ref().sim_tick

var stone:
	get: return _data.get_ref().stone

var task_events:
	get: return _data.get_ref().task_events

var terrain_changes:
	get: return _data.get_ref().terrain_changes

var tile_hh:
	get: return _data.get_ref().tile_hh

var tile_hw:
	get: return _data.get_ref().tile_hw

var tile_w:
	get: return _data.get_ref().tile_w

var trainings:
	get: return _data.get_ref().trainings

var units:
	get: return _data.get_ref().units

var view:
	get: return _scene.get_ref().view

var visibility:
	get: return _data.get_ref().visibility

var wood:
	get: return _data.get_ref().wood

func _attack_target_at(pos: Vector2) -> Dictionary:
	return _commands.get_ref()._attack_target_at(pos)

func _building_work_busy(building: Dictionary) -> bool:
	return _commands.get_ref()._building_work_busy(building)

func _cancel_site(site: Dictionary) -> bool:
	return _commands.get_ref()._cancel_site(site)

func _cancel_tech() -> bool:
	return _commands.get_ref()._cancel_tech()

func _cancel_training(building: Dictionary) -> bool:
	return _commands.get_ref()._cancel_training(building)

func _cell_of_px(px: float, py: float) -> Vector2i:
	return _commands.get_ref()._cell_of_px(px, py)

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	_commands.get_ref()._cmd_begin(kind, data)

func _cmd_disband() -> void:
	_commands.get_ref()._cmd_disband()

func _cmd_rest() -> void:
	_commands.get_ref()._cmd_rest()

func _cmd_watch() -> void:
	_commands.get_ref()._cmd_watch()

func _commander_for(u: Dictionary) -> Dictionary:
	return _commands.get_ref()._commander_for(u)

func _duel_begin() -> void:
	_commands.get_ref()._duel_begin()

func _feedback(msg: String) -> void:
	_commands.get_ref()._feedback(msg)

func _group_recall(n: int) -> bool:
	return _commands.get_ref()._group_recall(n)

func focus_group(n: int) -> bool:
	return _commands.get_ref().focus_group(n)

func _hover_unit(pos: Vector2) -> Dictionary:
	return _commands.get_ref()._hover_unit(pos)

func _jimou_begin(idx: int) -> void:
	_commands.get_ref()._jimou_begin(idx)

func _order_form_up(officer_index: int) -> void:
	_commands.get_ref()._order_form_up(officer_index)

func _own_object_at(pos: Vector2) -> Dictionary:
	return _commands.get_ref()._own_object_at(pos)

func _research_for_building(building: Dictionary) -> Dictionary:
	return _commands.get_ref()._research_for_building(building)

func _resource_at(pos: Vector2) -> Dictionary:
	return _commands.get_ref()._resource_at(pos)

func _resources() -> Dictionary:
	return _commands.get_ref()._resources()

func _return_selected_cargo() -> void:
	_commands.get_ref()._return_selected_cargo()

func _save_game(slot := 0, title := "") -> bool:
	return _commands.get_ref()._save_game(slot, title)

func _select_click(pos: Vector2, add: bool) -> void:
	_commands.get_ref()._select_click(pos, add)

func _selected_construction_workers() -> Array:
	return _commands.get_ref()._selected_construction_workers()

func _selected_has_nonworker_attacker() -> bool:
	return _commands.get_ref()._selected_has_nonworker_attacker()

func _set_formation(idx: int) -> void:
	_commands.get_ref()._set_formation(idx)

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _commands.get_ref()._sheet_ref_for(unit_id, owner)

func _start_build(opt: Dictionary) -> void:
	_commands.get_ref()._start_build(opt)

func _start_tech(idx: int) -> bool:
	return _commands.get_ref()._start_tech(idx)

func _start_train(opt: Dictionary) -> void:
	_commands.get_ref()._start_train(opt)

func _unit_name(unit_id: int) -> String:
	return _commands.get_ref()._unit_name(unit_id)

func ai_level(owner: int) -> int:
	return _commands.get_ref().ai_level(owner)

func build_placement_at(pos: Vector2, opt: Dictionary) -> Dictionary:
	return _commands.get_ref().build_placement_at(pos, opt)

func building_block_reason(bid: int, owner: int = -1) -> String:
	return _commands.get_ref().building_block_reason(bid, owner)

func cmd_pending_kind() -> String:
	return _commands.get_ref().cmd_pending_kind()

func control_group_size(n: int) -> int:
	return _commands.get_ref().control_group_size(n)

func control_group_work_site(n: int) -> Dictionary:
	return _commands.get_ref().control_group_work_site(n)

func officer_rank_name(off: Dictionary) -> String:
	return _commands.get_ref().officer_rank_name(off)

func officers_for_selection(owner: int, sel: Array) -> Array:
	return _commands.get_ref().officers_for_selection(owner, sel)

func set_sim_speed(index: int) -> bool:
	return _commands.get_ref().set_sim_speed(index)

func stop_selected() -> void:
	_commands.get_ref().stop_selected()

func tech_block_reason(idx: int) -> String:
	return _commands.get_ref().tech_block_reason(idx)

func tech_cost(idx: int) -> Dictionary:
	return _commands.get_ref().tech_cost(idx)

func tech_cost_text(idx: int) -> String:
	return _commands.get_ref().tech_cost_text(idx)

func tech_effect_desc(idx: int) -> String:
	return _commands.get_ref().tech_effect_desc(idx)

func tech_is_next(idx: int) -> bool:
	return _commands.get_ref().tech_is_next(idx)

func tech_is_sell(idx: int) -> bool:
	return _commands.get_ref().tech_is_sell(idx)

func tech_research_active() -> bool:
	return _commands.get_ref().tech_research_active()

func tech_research_name() -> String:
	return _commands.get_ref().tech_research_name()

func tech_research_remaining() -> int:
	return _commands.get_ref().tech_research_remaining()

func tech_row(idx: int) -> Dictionary:
	return _commands.get_ref().tech_row(idx)

func tech_rows_for_building(bid: int) -> Array:
	return _commands.get_ref().tech_rows_for_building(bid)

func tech_tip(idx: int) -> String:
	return _commands.get_ref().tech_tip(idx)

func tech_unlocked(idx: int) -> bool:
	return _commands.get_ref().tech_unlocked(idx)

func train_types_for(bid: int, owner: int = -1) -> Array:
	return _commands.get_ref().train_types_for(bid, owner)

func _exit_tree() -> void:
	_commands = null

## Event playback uses this capability to distinguish a battle from the main menu.
func _save_extra() -> Dictionary:
	return _commands.get_ref()._save_extra()
