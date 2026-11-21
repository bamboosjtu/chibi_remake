extends RefCounted
const RuntimeState = preload("res://app/battle/runtime/battle_runtime_state.gd")
const PROXY_FIELDS := ["runtime", "presentation", "saver", "ready_to_save", "cam", "view", "sfx", "bgm", "remaster_art", "cheat_input_open", "hover_text", "show_units", "show_buildings", "hud_acc", "show_debug", "feedback_until", "feedback_observed", "feedback_text", "ev_count", "sec_visible", "drag_pan", "selecting", "sel_start", "sel_end"]

## Scene facade. App owns save/ready state; presentation owns nodes and UI transients.
## Both are injected by main.gd; this class exists for stable scene-facing names.

var runtime := RuntimeState.new()
var presentation: Object = null

var saver: RefCounted:
	get: return runtime.saver
	set(value): runtime.saver = value

var ready_to_save: bool:
	get: return runtime.ready_to_save
	set(value): runtime.ready_to_save = value

var cam: Camera2D:
	get: return presentation.cam if presentation != null else null
	set(value): if presentation != null: presentation.cam = value

var view: Node2D:
	get: return presentation.view if presentation != null else null
	set(value): if presentation != null: presentation.view = value

var sfx: Node:
	get: return presentation.sfx if presentation != null else null
	set(value): if presentation != null: presentation.sfx = value

var bgm: Node:
	get: return presentation.bgm if presentation != null else null
	set(value): if presentation != null: presentation.bgm = value

var remaster_art: Object:
	get: return presentation.remaster_art if presentation != null else null
	set(value): if presentation != null: presentation.remaster_art = value

var cheat_input_open: bool:
	get: return presentation.cheat_input_open if presentation != null else false
	set(value): if presentation != null: presentation.cheat_input_open = value

var hover_text: String:
	get: return presentation.hover_text if presentation != null else ""
	set(value): if presentation != null: presentation.hover_text = value

var show_units: bool:
	get: return presentation.show_units if presentation != null else true
	set(value): if presentation != null: presentation.show_units = value

var show_buildings: bool:
	get: return presentation.show_buildings if presentation != null else true
	set(value): if presentation != null: presentation.show_buildings = value

var hud_acc: float:
	get: return presentation.hud_acc if presentation != null else 0.0
	set(value): if presentation != null: presentation.hud_acc = value

var show_debug: bool:
	get: return presentation.show_debug if presentation != null else false
	set(value): if presentation != null: presentation.show_debug = value

var feedback_until: int:
	get: return presentation.feedback_until if presentation != null else 0
	set(value): if presentation != null: presentation.feedback_until = value

var feedback_observed: String:
	get: return presentation.feedback_observed if presentation != null else ""
	set(value): if presentation != null: presentation.feedback_observed = value

var feedback_text: String:
	get: return presentation.feedback_text if presentation != null else ""
	set(value): if presentation != null: presentation.feedback_text = value

var ev_count: int:
	get: return presentation.ev_count if presentation != null else 0
	set(value): if presentation != null: presentation.ev_count = value

var sec_visible: Dictionary:
	get: return presentation.sec_visible if presentation != null else {}
	set(value): if presentation != null: presentation.sec_visible = value

var drag_pan: bool:
	get: return presentation.drag_pan if presentation != null else false
	set(value): if presentation != null: presentation.drag_pan = value

var selecting: bool:
	get: return presentation.selecting if presentation != null else false
	set(value): if presentation != null: presentation.selecting = value

var sel_start: Vector2:
	get: return presentation.sel_start if presentation != null else Vector2.ZERO
	set(value): if presentation != null: presentation.sel_start = value

var sel_end: Vector2:
	get: return presentation.sel_end if presentation != null else Vector2.ZERO
	set(value): if presentation != null: presentation.sel_end = value

func reset_transients() -> void:
	if presentation != null:
		presentation.reset_transients()
