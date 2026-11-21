extends RefCounted
## Presentation-owned scene state. No save service, no simulation rule.
var cam: Camera2D
var view: Node2D = null
var sfx: Node = null
var bgm: Node = null
var remaster_art: Object = null
var cheat_input_open := false
var hover_text := ""
var show_units := true
var show_buildings := true
var hud_acc := 0.0
var show_debug := false
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
