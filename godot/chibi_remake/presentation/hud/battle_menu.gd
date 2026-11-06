extends CanvasLayer
## 战场菜单独立拥有暂停和模态输入；保存／恢复仍走宿主的存档服务。
var host: Node2D
var overlay: ColorRect
var status: Label
var buttons: Array[Button] = []
var is_open := false
var leave_button: Button
var panel: PanelContainer
var menu_font: SystemFont
var surface_cache := {}
var settings_panel: PanelContainer
var speed_buttons: Array[Button] = []
var slots_dialog: CanvasLayer

func _init(h: Node2D) -> void:
	host = h
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

func _ready() -> void:
	menu_font = SystemFont.new()
	menu_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Noto Serif CJK SC"])
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.18)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440; panel.offset_right = 440
	panel.offset_top = -214; panel.offset_bottom = 214
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("252a2b")
	frame.border_color = Color("c8a452")
	frame.set_border_width_all(3)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 8
	frame.content_margin_left = 22; frame.content_margin_right = 22
	frame.content_margin_top = 18; frame.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", _surface_style(false))
	overlay.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)
	var title := Label.new()
	title.text = "系  统  选  单"
	title.add_theme_font_override("font", menu_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff7d5"))
	list.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 14)
	list.add_child(grid)
	var names := ["读取进度", "存储进度", "战役任务", "设置选项", "系统帮助", "结束战役"]
	var actions := [load_game, save_game, show_mission, show_settings, show_help, return_to_menu]
	for i in range(names.size()):
		var button := _wood_button(names[i], actions[i])
		grid.add_child(button)
		buttons.append(button)
	var resume_button := _wood_button("返 回 游 戏", close)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_button.custom_minimum_size.x = 400
	list.add_child(resume_button)
	leave_button = _wood_button("不保存，返回主菜单", _leave)
	list.add_child(leave_button)
	leave_button.hide()
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(status)
	_build_settings()
	slots_dialog=preload("res://presentation/hud/save_slots_dialog.gd").new()
	add_child(slots_dialog)
	slots_dialog.confirmed.connect(_slot_confirmed)
	slots_dialog.cancelled.connect(func():panel.show())
	overlay.hide()

func open() -> void:
	if host.view.briefing!=null and host.view.briefing.is_open:host.view.briefing.close()
	if host.player_commands != null: host.player_commands.pump()
	slots_dialog.dismiss()
	_close_settings()
	var vp := get_viewport().get_visible_rect().size
	var k := minf(1.0, minf(vp.x / 1000.0, vp.y / 600.0))
	panel.scale = Vector2.ONE * k
	panel.pivot_offset = Vector2(440, 214)
	settings_panel.scale = panel.scale
	settings_panel.pivot_offset = panel.pivot_offset
	is_open = true
	overlay.show()
	status.text = ""
	leave_button.hide()
	buttons[0].disabled = not Game.has_save()
	get_tree().paused = true
	buttons[0].grab_focus()

func close() -> void:
	slots_dialog.dismiss()
	_close_settings()
	is_open = false
	overlay.hide()
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if host.view.briefing!=null and host.view.briefing.is_open:return
	if is_instance_valid(slots_dialog) and slots_dialog.overlay.visible:return
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel.visible: _close_settings()
		else: close()
		get_viewport().set_input_as_handled()

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -440; settings_panel.offset_right = 440
	settings_panel.offset_top = -214; settings_panel.offset_bottom = 214
	settings_panel.add_theme_stylebox_override("panel",_surface_style(false))
	overlay.add_child(settings_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",20)
	settings_panel.add_child(list)
	var title := Label.new()
	title.text = "设  置  选  项"
	title.add_theme_font_override("font",menu_font)
	title.add_theme_font_size_override("font_size",32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	var label := Label.new()
	label.text = "游戏速度"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",24)
	list.add_child(label)
	var grid := GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",30)
	grid.add_theme_constant_override("v_separation",14)
	list.add_child(grid)
	for i in range(4):
		var button := _wood_button(str(host.clock.LABELS[i]),_select_speed.bind(i))
		grid.add_child(button)
		speed_buttons.append(button)
	var back := _wood_button("返回系统选单",_close_settings)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(back)
	settings_panel.hide()

func show_settings() -> void:
	panel.hide()
	settings_panel.show()
	_update_speed_buttons()
	speed_buttons[host.clock.speed_index].grab_focus()

func _close_settings() -> void:
	settings_panel.hide()
	panel.show()

func _select_speed(index: int) -> void:
	host.commands.world.set_sim_speed(index)
	_update_speed_buttons()

func _update_speed_buttons() -> void:
	for i in range(speed_buttons.size()):
		speed_buttons[i].text = str(host.clock.LABELS[i]) + (" · 当前" if i==host.clock.speed_index else "")

func save_game() -> void:
	panel.hide()
	slots_dialog.open(true,Game.campaign_caption(str(host.map_id)))

func load_game() -> void:
	panel.hide()
	slots_dialog.open(false)

func _slot_confirmed(slot: int, title: String) -> void:
	if slots_dialog.saving:
		if not host.commands.session._save_game(slot,title):
			slots_dialog.show_error("保存失败（%s），原有记录已保留。" % str(Game.last_save_error.get("stage","unknown")));return
		slots_dialog.dismiss();panel.show()
		status.text="保存成功 · 记录 %02d" % slot
		status.tooltip_text="存档位置："+ProjectSettings.globalize_path(Game.save_slot_path(slot))
		buttons[0].disabled=not Game.has_save();return
	var data: Dictionary=Game.load_save(slot)
	var map_id:=str(data.get("map",""))
	if data.is_empty() or not FileAccess.file_exists("res://data/%s.json" % map_id):
		slots_dialog.show_error("所选进度无法读取，原有记录已保留。");return
	if map_id!=str(host.map_id):
		Game.current_map=map_id;Game.pending_load=true;Game.pending_load_slot=slot
		get_tree().paused=false;get_tree().change_scene_to_file("res://main.tscn");return
	var selection := []
	for unit in host.selected: selection.append(int(unit.uid))
	if host.saver.apply_snapshot(data):
		var by_uid := {}
		for unit in host.units: by_uid[int(unit.uid)] = unit
		for uid in selection:
			if by_uid.has(uid): host.selected.append(by_uid[uid])
		close()
		host.view.update_panel()
	else:
		slots_dialog.show_error("进度与当前关卡内容不匹配，原有记录已保留。")

func return_to_menu() -> void:
	if not host.commands.session._save_game():
		status.text = "保存失败：%s（错误%d）\n位置：%s\n旧存档已保留，请检查该目录或返回游戏重试。" % [str(Game.last_save_error.get("stage", "unknown")), int(Game.last_save_error.get("code", FAILED)), str(Game.last_save_error.get("directory", Game.SAVE_PATH.get_base_dir()))]
		leave_button.show()
		return
	_leave()

func quit_game() -> void:
	# 退出前先落盘；失败则留在菜单并提示，避免“点退出丢进度”。
	if host.commands.session._save_game():
		get_tree().quit()
	else:
		status.text = "保存失败，未退出。请重试、返回游戏，或选择不保存返回主菜单。"
		leave_button.show()

func _leave() -> void:
	# change_scene removes the old scene immediately; do not call get_tree on it afterwards.
	var tree := get_tree()
	tree.paused = false
	var error := tree.change_scene_to_file("res://menu.tscn")
	if error != OK:
		tree.paused = true
		status.text = "无法返回主菜单（%d），请重试。" % error
		return

func show_mission() -> void:
	host.view.briefing.open()

func show_help() -> void:
	status.text = "左键选择，右键移动/交互；Q W E / A S D / Z X C 对应九宫格。\n工人运输：点击树林、粮田、铁矿或民居采集。Esc 返回。"

func _wood_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(370, 48)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", menu_font)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := _surface_style(true)
		if state == "hover": style.modulate_color = Color(1.25, 1.18, 1.08)
		if state == "pressed": style.modulate_color = Color(0.75, 0.75, 0.75)
		if state == "disabled": style.modulate_color = Color(0.65, 0.65, 0.65)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("ffdf83"))
	button.add_theme_color_override("font_hover_color", Color("fff3ba"))
	button.add_theme_color_override("font_disabled_color", Color("9b8761"))
	button.pressed.connect(action)
	return button

## Procedural stone and wood surfaces remain sharp without restoring extracted low-res UI.
func _surface_style(wood: bool) -> StyleBoxTexture:
	if surface_cache.has(wood): return surface_cache[wood].duplicate()
	var dimensions := Vector2i(512, 64) if wood else Vector2i(512, 256)
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1997
	noise.frequency = 0.035 if wood else 0.045
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var n := noise.get_noise_2d(float(x) * (0.12 if wood else 1.0), float(y) * (3.0 if wood else 1.0))
			var shade := 0.5 + n * 0.3
			var color := Color(0.29 + shade * 0.22, 0.13 + shade * 0.16, 0.06 + shade * 0.09) if wood else Color(0.09 + shade * 0.13, 0.12 + shade * 0.13, 0.13 + shade * 0.13)
			var edge := mini(mini(x, dimensions.x - 1 - x), mini(y, dimensions.y - 1 - y))
			if edge < 2: color = Color("41311e")
			elif edge < 4: color = Color("c39b59")
			elif edge < 6: color = Color("644d30")
			elif wood and (y < 10 or y > dimensions.y - 11): color *= 0.65
			image.set_pixel(x, y, color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8)
		style.set_content_margin(side, 18 if not wood else 8)
	surface_cache[wood] = style
	return style.duplicate()
