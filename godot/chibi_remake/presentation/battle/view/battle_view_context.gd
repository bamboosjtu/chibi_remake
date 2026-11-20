extends Node2D
## Shared by the HUD, camera, terrain and effects in one scene subtree.
var queries: RefCounted
var actions: RefCounted
var session_actions: RefCounted
var _scene: RefCounted

func _init(scene: RefCounted, reader: RefCounted, player_actions: RefCounted = null, session: RefCounted = null) -> void:
	_scene = scene
	queries = reader
	actions = player_actions
	session_actions = session

func is_battle_context() -> bool:
	return true

var cheat_input_open:
	get: return _scene.cheat_input_open

var cam:
	get: return _scene.cam

var ev_count:
	get: return _scene.ev_count

var feedback_text:
	get: return _scene.feedback_text

var hover_text:
	get: return _scene.hover_text
	set(value): _scene.hover_text = value

var remaster_art:
	get: return _scene.remaster_art

var sec_visible:
	get: return preload("res://simulation/definitions/frozen_data.gd").copy(_scene.sec_visible)

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

var view:
	get: return _scene.view
