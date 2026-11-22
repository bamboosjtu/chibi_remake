extends CanvasLayer
const SessionActions = preload("res://app/battle/session/session_actions.gd")
## Continue normal victories without displaying the end-of-campaign panel.
var host: Node2D
var panel: PanelContainer
var message: Label
var next_button: Button
var is_open := false
var pause_token := 0
var advancing := false
var automatic := true
var has_next_level := false

func _init(h: Node2D) -> void:
	host = h; layer = 46; process_mode = Node.PROCESS_MODE_ALWAYS
	automatic = DisplayServer.get_name() != "headless" and not "--script" in OS.get_cmdline_args() \
		and not "--selftest" in OS.get_cmdline_user_args() and not "--demo" in OS.get_cmdline_user_args()

func _ready() -> void:
	panel = PanelContainer.new(); add_child(panel)
	panel.add_theme_stylebox_override("panel", host.view.battle_menu._surface_style(false))
	var box := VBoxContainer.new(); panel.add_child(box)
	box.add_theme_constant_override("separation", 12)
	message = Label.new(); message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 24); box.add_child(message)
	var buttons := HBoxContainer.new(); box.add_child(buttons)
	next_button = host.view.battle_menu._wood_button("下一关", advance)
	buttons.add_child(next_button)
	buttons.add_child(host.view.battle_menu._wood_button("留在战场", stay))
	panel.hide(); get_viewport().size_changed.connect(_fit)

func open(kind: int) -> bool:
	if not automatic or bool(host.queries.cli_mode): return false
	if is_open: return advancing and not panel.visible
	is_open = true
	var map_id := str(host.queries.map_id)
	has_next_level = kind == 1 and not Game.next_level(map_id).is_empty()
	pause_token = SessionActions.pause(self,"battle completion")
	if has_next_level:
		advancing = true
		# Finish the current simulation or restore callback before changing scenes.
		_load_next_level.call_deferred(map_id, pause_token)
		return true
	_show_panel("战役完成" if kind == 1 else "战役结束")
	return false

func _show_panel(text: String) -> void:
	next_button.text = "下一关" if has_next_level else "返回主菜单"
	message.text = text
	panel.show()
	_fit()
	next_button.grab_focus()

func _load_next_level(map_id: String, token: int) -> void:
	if not is_inside_tree() or not advancing or pause_token != token: return
	if Game.advance_campaign(map_id): return
	advancing = false
	_show_panel("下一关无法载入，请重试。")

func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.reset_size()
	panel.position = ((vp-panel.size)*Vector2(0.5, 0.73)).floor()

func stay() -> void:
	SessionActions.resume(pause_token); pause_token = 0
	if not has_next_level:
		message.text = "战役结束，可返回主菜单。"

func reset() -> void:
	is_open = false; has_next_level = false; advancing = false; panel.hide()
	SessionActions.resume(pause_token); pause_token = 0

func advance() -> void:
	if advancing: return
	advancing = true
	if pause_token == 0: pause_token = SessionActions.pause(self,"battle completion")
	if has_next_level:
		_load_next_level(str(host.queries.map_id), pause_token)
	elif Game.return_to_menu() != OK:
		advancing = false; message.text = "主菜单无法载入，请重试。"
