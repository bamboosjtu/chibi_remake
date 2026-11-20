extends Node2D
## Battle composition root. Rules and state live in composed services.
const UnitProjection = preload("res://app/read_models/unit_projection.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
const CombatRules = preload("res://simulation/definitions/combat_rules.gd")
const UnitFootprint = preload("res://simulation/navigation/unit_footprint.gd")
const SPEED = Config.SPEED
const SIM_DT = Config.SIM_DT
const SIM_MAX_CATCHUP = Config.SIM_MAX_CATCHUP
const PRODUCE_BY_BUILDING = Config.PRODUCE_BY_BUILDING
const GATHER_REACH = Config.GATHER_REACH
const EDGE_DISTANCE = Config.EDGE_DISTANCE
const DEPOSIT_EDGE_PX = Config.DEPOSIT_EDGE_PX
const SCRIPTED_OBJECTIVES = Config.SCRIPTED_OBJECTIVES
const SPECIAL_OBJECTIVE_MISSIONS = Config.SPECIAL_OBJECTIVE_MISSIONS
const BootstrapService = preload("res://app/battle/bootstrap.gd")
var bootstrap: BootstrapService
const CheatControllerService = preload("res://app/battle/cheat_controller.gd")
var cheat_controller: CheatControllerService
const DuelControllerService = preload("res://app/battle/duel_controller.gd")
var duel_controller: DuelControllerService
const SceneControllerService = preload("res://app/battle/scene_controller.gd")
var scene_controller: SceneControllerService
var actions := preload("res://app/battle_actions.gd").new(self)
var session_actions := preload("res://app/session_actions.gd").new(self)
var world := preload("res://simulation/world/battle_world.gd").new()
const State = preload("res://simulation/state/battle_state.gd")
var state: State:
	get: return world.state
var scene := preload("res://app/battle_scene_state.gd").new()
var _state_fields: Dictionary = {}
var _scene_fields: Dictionary = {}
var _presentation_diagnostics := preload("res://presentation/battle/view/event_diagnostics.gd").new()

var ai: RefCounted:
	get: return world.ai
	set(value): world.ai = value

var rules: RefCounted:
	get: return world.rules
	set(value): world.rules = value

var command_rules: RefCounted:
	get: return world.command_rules

var player_commands: RefCounted:
	get: return world.player_commands

var economy: RefCounted:
	get: return world.economy
var projectiles: RefCounted:
	get: return world.projectiles
var fire_fields: RefCounted:
	get: return world.fire_fields
var transports: RefCounted:
	get: return world.transports
var harvesting: RefCounted:
	get: return world.harvesting
var construction: RefCounted:
	get: return world.construction
var stratagems: RefCounted:
	get: return world.stratagems
var effects: RefCounted:
	get: return world.effects
var nav: RefCounted:
	get: return world.nav
var visibility: RefCounted:
	get: return world.visibility
var automatic_gates: RefCounted:
	get: return world.automatic_gates
var clock: RefCounted:
	get: return world.clock

var view: Node2D:
	get: return scene.view
	set(value): scene.view = value

var cam: Camera2D:
	get: return scene.cam
	set(value): scene.cam = value

var sfx: Node:
	get: return scene.sfx
	set(value): scene.sfx = value

var bgm: Node:
	get: return scene.bgm
	set(value): scene.bgm = value

var saver: RefCounted:
	get: return scene.saver
	set(value): scene.saver = value

var _api_missing: Array = []
var _disposed := false

func _init() -> void:
	if not preload("res://simulation/definitions/rule_catalog.gd").is_ready(): return
	for field in state.PROXY_FIELDS: _state_fields[field] = true
	for field in scene.PROXY_FIELDS: _scene_fields[field] = true
	bootstrap = BootstrapService.new(scene, self)
	cheat_controller = CheatControllerService.new(scene, self)
	duel_controller = DuelControllerService.new(scene, self)
	scene_controller = SceneControllerService.new(scene, self)
	_bind_controllers()
	var report: Dictionary = world.validate_services("main", {"bootstrap":bootstrap, "cheat_controller":cheat_controller, "duel_controller":duel_controller, "scene_controller":scene_controller})
	_api_missing = report.missing
	if _api_missing.is_empty(): _activate_world()

func create_view_context() -> Node2D:
	var queries := preload("res://app/read_models/battle_queries.gd").new(self)
	var reader := preload("res://presentation/battle/view/battle_view_context.gd").new(scene, queries, actions, session_actions)
	add_child(reader)
	reader.add_to_group("active_battle_queries")
	return reader

func _activate_world() -> void:
	world.battle_simulation.connect_native()
	if not world.player_commands.commands_applied.is_connected(_commands_applied.bind(world.get_instance_id())):
		world.player_commands.commands_applied.connect(_commands_applied.bind(world.get_instance_id()), CONNECT_DEFERRED)
	if not world.effects.visual_requested.is_connected(_on_visual): world.effects.visual_requested.connect(_on_visual)
	if not world.effects.sound_requested.is_connected(_on_sound): world.effects.sound_requested.connect(_on_sound)
	if not world.effects.duel_requested.is_connected(_on_duel): world.effects.duel_requested.connect(_on_duel)

func _get(key: StringName):
	if _state_fields.has(key): return state.get(key)
	if _scene_fields.has(key): return scene.get(key)
	preload("res://property_contract.gd").reject(self,key)
	return null

func _set(key: StringName, value) -> bool:
	if key == "map_data":
		world.set_definition(value)
		state.map_data = value
		return true
	if _state_fields.has(key): state.set(key, value); return true
	if _scene_fields.has(key): scene.set(key, value); return true
	preload("res://property_contract.gd").reject(self,key)
	return false

func _on_visual(action: String, arguments: Array) -> void:
	if action == "feedback":
		scene.feedback_text = str(arguments[0])
		scene.feedback_until = 0
		return
	if scene.view == null: return
	if action in ["world_dirty","place_unit","free_unit","update_visual","attach_unit","set_unit_attached"]:
		scene.view.domain_changed()
	if world.effects.simulating and action in ["place_unit","fade_unit","hide_unit","update_visual","set_frame"]:
		scene.view.queue_visual(int(arguments[0].uid));return
	match action:
		"world_dirty": scene.view.queue_world_visuals()
		"impact": scene.view.projectile_view.impact(arguments[0])
		"place_unit": scene.view.place_unit(UnitProjection.event_record(arguments[0]))
		"fade_unit": scene.view.fade_unit(UnitProjection.event_record(arguments[0]),arguments[1])
		"hide_unit": scene.view.hide_unit(UnitProjection.event_record(arguments[0]))
		"capture_motion": scene.view.capture_motion()
		"free_unit": scene.view.free_unit(UnitProjection.event_record(arguments[0]))
		"update_visual": scene.view.update_visual(UnitProjection.event_record(arguments[0]))
		"set_frame": scene.view.set_frame(UnitProjection.event_record(arguments[0]),arguments[1])
		"attach_unit": scene.view.attach_unit(UnitProjection.event_record(arguments[0]), str(arguments[1].get("sheet","")), arguments[2], arguments[3], arguments[4])
		"show_end":
			_presentation_diagnostics.report()
			scene.view.show_end(arguments[0])
		"update_panel": scene.view.update_panel()
		"set_unit_attached": scene.view.set_unit_attached(UnitProjection.event_record(arguments[0]),arguments[1])
		_: _presentation_diagnostics.unknown("visual", action)

func _on_sound(action: String, arguments: Array) -> void:
	if scene.sfx == null: return
	match action:
		"play_select":
			var mobile := false
			var hero := false
			for unit: Dictionary in arguments[0]:
				if unit.is_building: continue
				mobile = true
				if not unit.get("officer", {}).is_empty(): hero = true
			if mobile: scene.sfx.play_select(hero)
		"play_attack": scene.sfx.play_attack(int(arguments[0].unit), int(arguments[0].get("atk_range", 1)))
		"play_id": scene.sfx.play_id(arguments[0])
		_: _presentation_diagnostics.unknown("sound", action)

func _ready() -> void:
	if not Game.startup_valid:
		set_process(false); return
	# Validate all required providers before initializing a map.
	# The same explicit contract check runs in exported builds.
	if preload("res://composition_contract.gd").abort_if_broken("main", _api_missing): return
	await bootstrap._ready()
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose_services()
		return
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST: return
	scene_controller._notification(what)
func _unhandled_input(event: InputEvent) -> void:
	scene_controller._unhandled_input(event)
func _process(delta: float) -> void:
	scene_controller._process(delta)
func _exit_tree() -> void:
	# A controller may be on the stack when change_scene removes this node.
	# Stop delivery now. PREDELETE releases the scene-owned behaviors.
	if not _disposed and world.player_commands != null:
		world.effects.close()
		world.player_commands.retire()
		world.battle_simulation.disconnect_native()

func dispose_services() -> void:
	if _disposed: return
	_disposed = true
	_presentation_diagnostics.report()
	for service in [bootstrap, cheat_controller, duel_controller, scene_controller]:
		if is_instance_valid(service): service.free()
	world.dispose()



func _on_duel(outcome: String, onm: String, enm: String) -> void:
	duel_controller._present_duel(outcome, onm, enm)

func exchange_world(next_world: RefCounted) -> RefCounted:
	var previous: RefCounted = world
	previous.effects.visual_requested.disconnect(_on_visual)
	previous.effects.sound_requested.disconnect(_on_sound)
	previous.effects.duel_requested.disconnect(_on_duel)
	previous.player_commands.commands_applied.disconnect(_commands_applied.bind(previous.get_instance_id()))
	world = next_world
	_bind_controllers()
	_activate_world()
	return previous

func _commands_applied(epoch: int) -> void:
	if _disposed or not is_inside_tree() or epoch != world.get_instance_id(): return
	if scene.view != null: scene.view.update_panel()


func _bind_controllers() -> void:
	if bootstrap != null: bootstrap.bind_dependencies(self)
	if cheat_controller != null: cheat_controller.bind_dependencies(self)
	if scene_controller != null: scene_controller.bind_dependencies(self)
