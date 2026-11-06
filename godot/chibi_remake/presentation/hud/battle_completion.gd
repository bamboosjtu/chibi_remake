extends CanvasLayer
## Presentation owns the short victory countdown; Game owns chapter selection.
var host: Node2D
var panel: PanelContainer
var message: Label
var next_button: Button
var is_open := false
var advancing := false
var seconds := 5.0
var automatic := true
var countdown := false
var next_entry := {}

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

func open(kind: int) -> void:
	if is_open or not automatic or bool(host.cli_mode): return
	is_open = true; advancing = false; seconds = 5.0
	next_entry = Game.next_level(str(host.map_id))
	countdown = kind == 1 and not next_entry.is_empty()
	next_button.text = "下一关" if countdown else "返回主菜单"
	_refresh(kind); panel.show(); _fit(); get_tree().paused = true
	next_button.grab_focus()

func _refresh(kind: int) -> void:
	if countdown:
		message.text = "%d 秒后进入 %s · %s" % [ceili(seconds), str(next_entry.chapter), str(next_entry.title)]
	else: message.text = "战役完成" if kind == 1 else "战役结束"

func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.reset_size()
	panel.position = ((vp-panel.size)*Vector2(0.5, 0.73)).floor()

func _process(delta: float) -> void:
	if not is_open or advancing or not countdown: return
	seconds = maxf(0, seconds-delta); _refresh(1)
	if seconds <= 0: advance()

func stay() -> void:
	countdown = false; get_tree().paused = false
	message.text = "自动跳转已取消，可随时进入下一关。" if not next_entry.is_empty() and int(host.game_end)==1 else "战役结束，可返回主菜单。"

func reset() -> void:
	is_open = false; countdown = false; advancing = false; panel.hide()

func advance() -> void:
	if advancing: return
	advancing = true; countdown = false; get_tree().paused = false
	if int(host.game_end) == 1 and not Game.next_level(str(host.map_id)).is_empty():
		if not Game.advance_campaign(str(host.map_id)):
			advancing = false; message.text = "下一关无法载入，请返回主菜单重试。"
	else:
		Game.pending_load = false; Game.pending_load_slot = 0
		get_tree().change_scene_to_file("res://menu.tscn")
