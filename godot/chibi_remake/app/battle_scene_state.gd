extends RefCounted
const PROXY_FIELDS := ["saver", "cam", "bgm", "sfx", "remaster_art", "view", "cheat_input_open", "hover_text", "show_units", "show_buildings", "hud_acc", "show_debug", "ready_to_save", "feedback_until", "feedback_observed", "feedback_text", "ev_count", "sec_visible", "drag_pan", "selecting", "sel_start", "sel_end"]
## Scene-owned services and nodes. No simulation rules.
const RemasterArt = preload("res://presentation/battle/art_catalog.gd")




var saver: RefCounted = null                        # 需要宿主，所以在 _ready 里用 self 造

var cam: Camera2D
# info / panel_label / officer_portrait / end_label 已随 ARCH-013 搬到 battle_view.gd

var bgm: Node = null            # 战场 BGM

var sfx: Node = null            # 原版 WAVE.EXP 音效（选中/攻击）

var remaster_art := RemasterArt.new()

var view: Node2D = null                             # ARCH-013：表现层宿主（--simtest/--noview 时为 null）

var cheat_input_open := false

var hover_text := ""

var show_units := true

var show_buildings := true

var hud_acc := 0.0

var show_debug := false          # ARCH-011：工程信息默认不显示给玩家（F3 切换）

var ready_to_save := false

var feedback_until := 0
var feedback_observed := ""

var feedback_text := ""
var ev_count := 0
var sec_visible := {}
var drag_pan := false
var selecting := false
var sel_start := Vector2.ZERO
var sel_end := Vector2.ZERO

func reset_transients() -> void:
	drag_pan = false
	selecting = false
	sel_start = Vector2.ZERO
	sel_end = Vector2.ZERO
	feedback_text = ""
	feedback_until = 0
	feedback_observed = ""
	hover_text = ""
