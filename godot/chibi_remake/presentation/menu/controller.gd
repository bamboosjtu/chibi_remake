extends Object
const MenuCatalog = preload("res://presentation/menu/menu_catalog.gd")
const SessionActions = preload("res://app/battle/session/session_actions.gd")
## controller: presentation component.
const UIState = preload("res://presentation/menu/menu_state.gd")
var _ui: UIState
var surface: Control
var _automation_driver: Object
var _dep_campaign_dialog: Object
var _dep_level_dialog: Object
var _dep_menu_styles: Object

func _probe_missing() -> bool:
	if _automation_driver != null: return false
	printerr("MENU HARNESS FAIL: acceptance driver unavailable")
	surface.get_tree().quit(1)
	return true
const RemasterArt = preload("res://presentation/battle/resources/art_catalog.gd")

const CAMPAIGN_CAO := MenuCatalog.CAMPAIGN_CAO

func _init(data: UIState, node: Control) -> void:
	_ui = data
	surface = node

func _ready() -> void:
	surface.get_window().title = "三国赤壁 · 高清重制"
	surface.get_tree().set_auto_accept_quit(false)
	_dep_menu_styles._build_styles()
	_build_menu_backdrop()
	_build_main_buttons()
	_build_toast()
	_dep_level_dialog._build_level_dialog()
	_dep_campaign_dialog._build_campaign_dialog()
	await _finish_menu_startup()

func _build_menu_backdrop() -> void:
	var bgm = load("res://presentation/audio/bgm.gd").new()
	surface.add_child(bgm)
	bgm.play("res://media/music/start.ogg")
	var bg := TextureRect.new()
	var art := RemasterArt.new()
	var remaster_background := art.menu_background()
	bg.texture = remaster_background
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	surface.add_child(bg)
	if remaster_background != null:
		_ui.title_label = Label.new()
		_ui.title_label.text = "赤壁之战"
		_ui.title_label.anchor_left = 0.5
		_ui.title_label.anchor_right = 0.5
		_ui.title_label.anchor_top = 0.20
		_ui.title_label.anchor_bottom = 0.20
		_ui.title_label.offset_left = -350
		_ui.title_label.offset_right = 350
		_ui.title_label.offset_top = -55
		_ui.title_label.offset_bottom = 65
		_ui.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.title_label.add_theme_font_size_override("font_size", 92)
		_ui.title_label.add_theme_color_override("font_color", Color("d6b176"))
		_ui.title_label.add_theme_color_override("font_outline_color", Color("281810"))
		_ui.title_label.add_theme_constant_override("outline_size", 4)
		_ui.title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(_ui.title_label)
		_ui.subtitle_label = Label.new()
		_ui.subtitle_label.text = "三国赤壁 · 高清重制"
		_ui.subtitle_label.anchor_left = 0.5
		_ui.subtitle_label.anchor_right = 0.5
		_ui.subtitle_label.anchor_top = 0.32
		_ui.subtitle_label.anchor_bottom = 0.32
		_ui.subtitle_label.offset_left = -300
		_ui.subtitle_label.offset_right = 300
		_ui.subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.subtitle_label.add_theme_font_size_override("font_size", 24)
		_ui.subtitle_label.add_theme_color_override("font_color", Color("d6b176"))
		_ui.subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(_ui.subtitle_label)

func _build_main_buttons() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.545, 0.333, 0.145, 0.92)
	sb.border_color = Color(0.30, 0.16, 0.05)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.66, 0.43, 0.20, 0.95)

	var items := [
		["开始游戏", 0.575, _on_start],
		["读取进度", 0.669, _on_load],
		["对战模式", 0.764, _on_skirmish],
		["历史简介", 0.857, _on_history],
		["退出游戏", 0.951, func(): surface.get_tree().quit()],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		b.anchor_left = 0.5
		b.anchor_right = 0.5
		b.anchor_top = float(it[1])
		b.anchor_bottom = float(it[1])
		b.offset_left = -170.0
		b.offset_right = 170.0
		b.offset_top = -30.0
		b.offset_bottom = 30.0
		b.pressed.connect(it[2])
		surface.add_child(b)
		_ui.main_buttons.append(b)

func _build_toast() -> void:
	_ui.toast = Label.new()
	_ui.toast.anchor_left = 0.5
	_ui.toast.anchor_right = 0.5
	_ui.toast.anchor_top = 0.40
	_ui.toast.anchor_bottom = 0.40
	_ui.toast.offset_left = -400.0
	_ui.toast.offset_right = 400.0
	_ui.toast.offset_top = -20.0
	_ui.toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.toast.add_theme_font_size_override("font_size", 22)
	_ui.toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_ui.toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_ui.toast.add_theme_constant_override("outline_size", 6)
	_ui.toast.visible = false
	surface.add_child(_ui.toast)

func _finish_menu_startup() -> void:
	# 直入关卡：--map=CHIBIC1（配合 --screenshot 可做发布版验证）
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--map=") and not Game.startup_map_consumed:
			Game.startup_map_consumed = true
			_on_level.call_deferred(a.substr(6).to_lower())
			return

	# 势力选择（2a 新增钩子）：
	#   --campaign             只把「选择势力」这一步摊开（截图 / 自检用）
	#   --campaign=cao|liu     直接替玩家把势力选好
	#     （别名：cao/chibic/wei=曹操，liu/chibil/shu=刘备；别的值忽略并退回默认）
	var want_campaign := false
	for a in args:
		if a == "--campaign":
			want_campaign = true
		elif a.begins_with("--campaign="):
			var c = _dep_campaign_dialog._campaign_alias(a.substr(11))
			if c != "":
				_ui.campaign = c
				_dep_campaign_dialog._set_campaign(c, false)

	# --levels：直接把关卡列表摊开（菜单截图 / 布局自检用）。必须和 --screenshot
	# 一起用，否则会停在菜单上等人操作。
	# 列表现在按势力过滤，所以没给 --campaign= 时默认曹操线，保证老钩子照样出行。
	if "--levels" in args:
		if _ui.campaign == "":
			_ui.campaign = CAMPAIGN_CAO
			_ui.campaign_choice = CAMPAIGN_CAO
		_on_start()
		_on_campaign_confirm()
	elif want_campaign:
		_on_start()

	# --keytest：把合成按键塞进视口输入流，验证「选择势力」那一步真的吃键盘
	#（← / → / A / D 换边、Enter 确定、Esc 取消）。放在截图之前，跑完直接退出。
	if "--keytest" in args:
		if _probe_missing(): return
		await _automation_driver._run_keytest()
		surface.get_tree().quit()
		return

	# --mousetest / --mouseclick=<target>：把合成的 InputEventMouseButton 塞进视口输入流，
	# 验证「选择势力」两块立绘格真的吃鼠标点击（gui_input 那条路，--keytest 覆盖不到）。
	# target 一律小写识别：slotL|slot0|cao|left..slotR|slot1|liu|right = 势力格自身中心，
	# outside = 面板外的固定点（80,80，点在遮罩上）；x,y = 显式视口坐标；
	# confirm = 金凸「确定」，cancel = 金凸「取消」。--mousetest 是完整矩阵，跑完即退。
	if "--mousetest" in args:
		if _probe_missing(): return
		await _automation_driver._run_mouse_matrix()
		surface.get_tree().quit()
		return
	var mc_cmd := ""
	for a in args:
		if a.begins_with("--mouseclick="):
			mc_cmd = a.substr(13)
			break
		elif a == "--mouseclick":
			mc_cmd = "unspecified"
			break
	if mc_cmd != "":
		if _probe_missing(): return
		await _automation_driver._run_mouse_click(mc_cmd)
		# 不带 --screenshot/--levels 时点完即退（否则挂在菜单上等人）；带了就落下去
		# 走截图那一段（它自己负责截图和退出）。
		if "--screenshot" not in args and "--levels" not in args:
			surface.get_tree().quit()
			return
	if "--screenshot" in args or "--levels" in args:
		await _capture_menu_probe(args, want_campaign)
		return

	if Game.last_load_error != "":
		var load_msg := Game.last_load_error
		Game.last_load_error = ""
		_show_toast.call_deferred(load_msg)

	_show_menu_intro(args)

func _show_menu_intro(args: PackedStringArray) -> void:
	_ui.media_view=preload("res://presentation/media/event_view.gd").new(surface);surface.add_child(_ui.media_view)
	var visible_args := Array(args).filter(func(arg): return not str(arg).begins_with("--portable-root=") and str(arg) != "--portable" and not str(arg).begins_with("--storage-mode="))
	if not Game.startup_video_seen and DisplayServer.get_name()!="headless" and visible_args.is_empty():
		Game.startup_video_seen=true
		_ui.media_view.play_startup_intro()

func _capture_menu_probe(args: PackedStringArray, want_campaign: bool) -> void:
	# 发布版自测截图：--screenshot（菜单本身）。
	# --levels 时可再跟 --scroll=N（把列表按像素滚到 N）、--focus=N（把焦点放到第 N 行，
	# 走的是键盘导航那条 follow_focus 路径）或 --scrollby=N（按 N 像素步进，
	# 走的是 ▲▼ 按钮的 _scroll_by 同一条路径）。
	await surface.get_tree().create_timer(0.8).timeout
	if "--levels" in args:
		if _probe_missing(): return
		_automation_driver._report_level_dialog()
		for a in args:
			if a.begins_with("--scroll="):
				_dep_level_dialog._scroll_to(int(a.substr(9)))
			elif a.begins_with("--focus="):
				_dep_level_dialog._focus_row(int(a.substr(8)))
			elif a.begins_with("--scrollby="):
				_dep_level_dialog._scroll_by(int(a.substr(11)))
		await surface.get_tree().process_frame
		await surface.get_tree().process_frame
		if "--levels" in args:
			if _probe_missing(): return
			_automation_driver._report_scroll_state()
	elif want_campaign:
		await surface.get_tree().process_frame
		await surface.get_tree().process_frame
		_dep_campaign_dialog._refresh_campaign_cursor()
		if _probe_missing(): return
		_automation_driver._report_campaign_dialog()
	if "--screenshot" in args: await _save_menu_screenshot(args)
	surface.get_tree().quit()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		surface.get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	# ── 「选择势力」开着时：←/→ 或 A/D 换边，Enter=确定，Esc=取消 ──
	# （两格和两个按钮都设成 FOCUS_NONE，所以这里收得到全部按键，不会被按钮吃掉）
	if _ui.campaign_panel != null and _ui.campaign_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_back()
			surface.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			_on_campaign_confirm()
			surface.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left"):
			_dep_campaign_dialog._move_campaign(-1)
			surface.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_dep_campaign_dialog._move_campaign(1)
			surface.get_viewport().set_input_as_handled()
			return
		if event is InputEventKey:
			var k := event as InputEventKey
			if k.pressed and not k.echo:
				var kc: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				if kc == KEY_A or kc == KEY_LEFT:
					_dep_campaign_dialog._move_campaign(-1)
					surface.get_viewport().set_input_as_handled()
				elif kc == KEY_D or kc == KEY_RIGHT:
					_dep_campaign_dialog._move_campaign(1)
					surface.get_viewport().set_input_as_handled()
		return
	# ── 关卡列表开着时：Esc = 返回（和改版前完全一致）──
	if _ui.level_panel != null and _ui.level_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_back()
		surface.get_viewport().set_input_as_handled()

func _show_toast(msg: String) -> void:
	_ui.toast.text = msg
	_ui.toast.visible = true
	_ui.toast_serial += 1
	var s := _ui.toast_serial
	await surface.get_tree().create_timer(2.6).timeout
	if s == _ui.toast_serial and _ui.toast != null:
		_ui.toast.visible = false

func _hide_toast() -> void:
	_ui.toast_serial += 1
	if _ui.toast != null:
		_ui.toast.visible = false

func _on_start() -> void:
	_hide_toast()
	for b in _ui.main_buttons:
		b.visible = false
	_ui.level_panel.visible = false
	if _ui.campaign != "":
		_ui.campaign_choice = _ui.campaign      # 上次选过的边默认高亮
	if _ui.campaign_panel != null:
		_ui.campaign_panel.visible = true
	if _ui.scrim != null:
		_ui.scrim.visible = true
	_dep_campaign_dialog._set_title_visible(false)           # 居中后的对话框会压住标题 → 干脆把标题/副标题收掉
	_dep_campaign_dialog._release_focus()
	_dep_campaign_dialog._refresh_campaign_cursor.call_deferred()

func _on_campaign_confirm() -> void:
	_ui.campaign = _ui.campaign_choice
	if _ui.campaign_panel != null:
		_ui.campaign_panel.visible = false
	if _ui.campaign_cursor != null:
		_ui.campaign_cursor.visible = false
	_dep_level_dialog._fill_level_list()
	_ui.level_panel.visible = true
	if _ui.scrim != null:
		_ui.scrim.visible = true
	_dep_campaign_dialog._set_title_visible(false)
	_dep_level_dialog._scroll_to(0)
	# 打开就把焦点放到第一行：方向键/回车立刻可用，Esc/滚轮也照常
	var first = _dep_level_dialog._first_row()
	if first != null:
		first.grab_focus()

func _on_back() -> void:
	_ui.level_panel.visible = false
	if _ui.campaign_panel != null:
		_ui.campaign_panel.visible = false
	if _ui.campaign_cursor != null:
		_ui.campaign_cursor.visible = false
	if _ui.scrim != null:
		_ui.scrim.visible = false
	_dep_campaign_dialog._set_title_visible(true)
	for b in _ui.main_buttons:
		b.visible = true
	_dep_campaign_dialog._release_focus()

func _on_skirmish() -> void:
	# 原版 FUN_00409D70 对 21000 是空处理：可点、无提示、无动作。严格复刻，不弹提示。
	return

func _on_history() -> void:
	if _ui.media_view!=null:_ui.media_view.play_media("res://media/videos/LISHI.AVI")

func _on_level(id: String) -> void:
	if Game.change_battle(id) != OK: _show_toast("关卡无法载入，请重试。")

func _on_load() -> void:
	if _ui.slots_dialog==null:
		_ui.slots_dialog=preload("res://presentation/shared/dialogs/save_slots_dialog.gd").new()
		surface.add_child(_ui.slots_dialog)
		_ui.slots_dialog.confirmed.connect(_load_slot)
	_ui.slots_dialog.open(false)

func _load_slot(slot: int, _title: String) -> void:
	match SessionActions.open_saved_battle(slot):
		OK: return
		ERR_FILE_CORRUPT: _ui.slots_dialog.show_error("所选进度无法读取")
		ERR_DOES_NOT_EXIST: _ui.slots_dialog.show_error("存档对应的关卡已不存在")
		_: _show_toast("进度无法载入，当前菜单已保留。")

func _save_menu_screenshot(args: PackedStringArray) -> void:
	var path := "user://chibi_shot.png"
	for argument in args:
		if argument.begins_with("--shot="):
			path = Game.diagnostic_path(argument.substr(7))
			if path.is_empty(): return
	await RenderingServer.frame_post_draw
	var texture := surface.get_viewport().get_texture()
	if texture != null:
		var image := texture.get_image()
		if image != null: image.save_png(path)

func bind_dependencies(components: Object) -> void:
	_automation_driver = components.automation_driver
	_dep_campaign_dialog = components.campaign_dialog
	_dep_level_dialog = components.level_dialog
	_dep_menu_styles = components.menu_styles
