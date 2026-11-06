extends Node2D
## Battle composition root. Rules and state live in composed services.
const Config = preload("res://simulation/battle_config.gd")
const CombatRules = preload("res://simulation/systems/combat_rules.gd")
const TECH_TABLE = Config.TECH_TABLE
const TECH_BUILDING_LINES = Config.TECH_BUILDING_LINES
const TECH_TICKS = Config.TECH_TICKS
const SPEED = Config.SPEED
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const UnitFootprint = preload("res://simulation/systems/unit_footprint.gd")
const SIM_DT = Config.SIM_DT
const SIM_MAX_CATCHUP = Config.SIM_MAX_CATCHUP
const Progression = preload("res://simulation/systems/officer_progression.gd")
const PRODUCE_BY_BUILDING = Config.PRODUCE_BY_BUILDING
const DEPOSIT_UNITS = Config.DEPOSIT_UNITS
const GATHER_TICKS = Config.GATHER_TICKS
const CARRY_CAPACITY = Config.CARRY_CAPACITY
const GATHER_SECONDS = Config.GATHER_SECONDS
const GATHER_REACH = Config.GATHER_REACH
const EDGE_DISTANCE = Config.EDGE_DISTANCE
const DEPOSIT_EDGE_PX = Config.DEPOSIT_EDGE_PX
const TRANSPORT_UNIT = Config.TRANSPORT_UNIT
const EXP_LEVELS = Config.EXP_LEVELS
const SCRIPTED_OBJECTIVES = Config.SCRIPTED_OBJECTIVES
const SPECIAL_OBJECTIVE_MISSIONS = Config.SPECIAL_OBJECTIVE_MISSIONS
var commands := preload("res://app/battle_commands.gd").new()
var _modules: Dictionary = {}
var _application_services: Dictionary = {}
var world := preload("res://simulation/battle_world.gd").new()
const State = preload("res://simulation/battle_state.gd")
var state: State:
	get: return world.state
var scene := preload("res://app/battle_scene_state.gd").new()
var _state_fields: Dictionary = {}
var _scene_fields: Dictionary = {}

var ai: RefCounted:
	get: return state.ai
	set(value): state.ai = value

var rules: RefCounted:
	get: return state.rules
	set(value): state.rules = value

var command_rules: RefCounted:
	get: return state.command_rules
	set(value): state.command_rules = value

var player_commands: RefCounted:
	get: return state.player_commands
	set(value): state.player_commands = value

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

var _access: Dictionary:
	get: return world._access
var _api_conflicts: Array = []
var _api_missing: Array = []

func _init() -> void:
	_modules = world._modules
	for property in state.get_property_list(): _state_fields[property.name] = true
	for property in scene.get_property_list(): _scene_fields[property.name] = true
	_wire_world()

func _wire_world() -> void:
	_modules = world._modules.duplicate()
	if not _application_services.has("bootstrap"): _application_services["bootstrap"] = preload("res://app/battle/bootstrap.gd").new(state, scene, self)
	if not _application_services.has("cheat_controller"): _application_services["cheat_controller"] = preload("res://app/battle/cheat_controller.gd").new(state, scene, self)
	if not _application_services.has("duel_controller"): _application_services["duel_controller"] = preload("res://app/battle/duel_controller.gd").new(state, scene, self)
	if not _application_services.has("scene_controller"): _application_services["scene_controller"] = preload("res://app/battle/scene_controller.gd").new(state, scene, self)
	_modules.merge(_application_services)
	var registry := preload("res://composition_contract.gd").wire(_modules, "main", _access)
	_api_conflicts = registry.conflicts
	_api_missing = registry.missing
	commands.connect_services(_modules)
	if not state.effects.visual_requested.is_connected(_on_visual): state.effects.visual_requested.connect(_on_visual)
	if not state.effects.sound_requested.is_connected(_on_sound): state.effects.sound_requested.connect(_on_sound)
	if not state.effects.duel_requested.is_connected(_on_duel): state.effects.duel_requested.connect(_on_duel)

func _get(key: StringName):
	if _state_fields.has(key): return state.get(key)
	if _scene_fields.has(key): return scene.get(key)
	return null

func _set(key: StringName, value) -> bool:
	if key == "map_data":
		world.set_definition(value)
		state.map_data = value
		return true
	if _state_fields.has(key): state.set(key, value); return true
	if _scene_fields.has(key): scene.set(key, value); return true
	return false

func _on_visual(action: String, arguments: Array) -> void:
	if scene.view == null: return
	match action:
		"impact": scene.view.projectile_view.impact(arguments[0])
		"place_unit": scene.view.place_unit(arguments[0])
		"fade_unit": scene.view.fade_unit(arguments[0],arguments[1])
		"hide_unit": scene.view.hide_unit(arguments[0])
		"capture_motion": scene.view.capture_motion()
		"free_unit": scene.view.free_unit(arguments[0])
		"update_visual": scene.view.update_visual(arguments[0])
		"set_frame": scene.view.set_frame(arguments[0],arguments[1])
		"attach_unit": scene.view.attach_unit(arguments[0],arguments[1],arguments[2],arguments[3],arguments[4])
		"show_end": scene.view.show_end(arguments[0])
		"update_panel": scene.view.update_panel()
		"set_unit_attached": scene.view.set_unit_attached(arguments[0],arguments[1])
		_: preload("res://composition_contract.gd").abort_if_broken("visual event",[],[{"method":action}])

func _on_sound(action: String, arguments: Array) -> void:
	if scene.sfx == null: return
	match action:
		"play_select": scene.sfx.play_select(arguments[0])
		"play_attack": scene.sfx.play_attack(arguments[0])
		"play_id": scene.sfx.play_id(arguments[0])
		_: preload("res://composition_contract.gd").abort_if_broken("sound event",[],[{"method":action}])

func _ready() -> void:
	# An ambiguous composition dispatches calls to the wrong service; never load
	# a map on top of that. registry.gd also enforces this in exported builds.
	if preload("res://composition_contract.gd").abort_if_broken("main", _api_conflicts, _api_missing): return
	await _modules["bootstrap"]._ready()
func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST: return
	_modules["scene_controller"]._notification(what)
func _unhandled_input(event: InputEvent) -> void:
	_modules["scene_controller"]._unhandled_input(event)
func _process(delta: float) -> void:
	_modules["scene_controller"]._process(delta)
func _exit_tree() -> void:
	dispose_services()

func dispose_services() -> void:
	if state.player_commands != null:
		state.player_commands.clear()
		for connection in state.player_commands.commands_applied.get_connections():
			state.player_commands.commands_applied.disconnect(connection.callable)
	commands.disconnect_services()
	for service in _application_services.values(): service.ports.disconnect_services()
	_application_services.clear()
	_modules.clear()
	world.dispose()

func simulation_access(domain: String) -> RefCounted:
	return _access[domain]


func _on_duel(outcome: String, onm: String, enm: String, ticket: int) -> void:
	_modules["duel_controller"]._present_duel(outcome, onm, enm, ticket)

func exchange_world(next_world: RefCounted) -> RefCounted:
	var previous: RefCounted = world
	world = next_world
	_wire_world()
	if state.player_commands != null:
		if not state.player_commands.commands_applied.is_connected(_commands_applied): state.player_commands.commands_applied.connect(_commands_applied)
	return previous

func _commands_applied() -> void:
	if scene.view != null: scene.view.update_panel()
