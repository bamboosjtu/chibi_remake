extends RefCounted
## controller: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/controller_dependencies.gd").new()
const RES_ICON_TEMPLATES := [
	"res://art/full/ui/res_%s.png",
	"res://art/full/ui/icon_%s.png",
]

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func maybe_play_intro(md: Dictionary) -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s == "--no-intro" or s == "--selftest" or s == "--noview" or s == "--smoketest" \
				or s == "--demo" or s == "--screenshot" or s == "--diag-nav" or s.begins_with("--simtest"):
			return
	var avi := str((md.get("scenario", {}) as Dictionary).get("avi", ""))
	var path:String=preload("res://presentation/media/event_view.gd").original_path(avi)
	if _ui.event_view != null and _ui.event_view.play_media(path):
		_ui.opening_pending=true
		print("INTRO: ", path)
	else:_ui.briefing.open()

func _intro_finished() -> void:
	if _ui.opening_pending:
		_ui.opening_pending=false;_ui.briefing.open()

func _res_icon_path(kind: String) -> String:
	for tpl in RES_ICON_TEMPLATES:
		var p: String = str(tpl) % kind
		if ResourceLoader.exists(p):
			return p
	return ""

func show_end(kind: int) -> void:
	if _ui.end_label == null:
		return
	_ui.end_label.text = "胜  利 ！" if kind == 1 else "败  北 ……"
	_ui.end_label.visible = true
	if _ui.completion != null: _ui.completion.open(kind)
