extends RefCounted
## hud input: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var _armed_button: WeakRef
var _armed_world := -1
var ports = preload("res://presentation/battle/components/ports/hud_input_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _process(_delta: float) -> void:
	draw_hover_at(surface.get_viewport().get_mouse_position())

func draw_hover_at(mp: Vector2) -> void:
	if _ui.art_tip == null:
		return
	var hit: Dictionary = _hud_button_at(mp)
	var nm := ""
	if not hit.is_empty() and str(hit.pool) == "art":
		var e: Dictionary = _ui.art_buttons[int(hit.idx)]
		nm = str((e.btn as TextureRect).get_meta("cmd_name", ""))
	elif not hit.is_empty() and str(hit.pool) == "cmd":
		nm = str(_ui.cmd_buttons[int(hit.idx)].get_meta("build_hint", ""))
	for item in _ui.art_buttons:
		var index: int=item.idx
		if not item.btn.visible:continue
		var held: bool=item.control.is_pressed() or _ui._hot_pressed==index
		var hover: bool=not hit.is_empty() and str(hit.pool)=="art" and int(hit.idx)==index
		ports._set_art_state(index,1 if held else (2 if hover else 0))
	if not hit.is_empty() and str(hit.pool)=="art" and nm!="":
		var entry: Dictionary=_ui.art_buttons[int(hit.idx)]
		var slot: int=int(hit.idx)-(9 if str(entry.sub)=="hot" else (18 if str(entry.sub)=="form" else 0))
		if str(entry.sub) == "form" and slot >= 8: slot -= 8
		elif str(entry.sub) in ["form_next", "form_prev"]: slot = 8
		if slot>=0 and slot<9:nm="(%s) %s" % [_ui.command_catalog.hotkeys[slot],nm]
	if nm != _ui._art_hover_name:
		_ui._art_hover_name = nm
		_ui.art_tip.visible = nm != ""
		_ui.art_tip.text = "  %s  " % nm
		_ui.info.visible = nm == "" and _ui.info.text != ""

func _clear_console_capture() -> void:
	if _ui._hot_pressed >= 0: ports._set_art_state(_ui._hot_pressed,0)
	_ui._hud_press_pool = ""
	_ui._hud_press_idx = -1
	_ui._hud_press_cancelled = true
	_ui._hud_panel_capture = false
	_ui._hot_pressed = -1
	_ui._hot_keycode = 0
	_ui._minimap_drag = false

func _input(event: InputEvent) -> void:
	if _dismiss_ability_menu(event): return
	if _ui.host.commands.session.handle_cheat_input(event):
		_clear_console_capture()
		surface.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _ui._minimap_drag:
		ports._minimap_navigate(event.position)
		surface.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _ui._minimap_drag:
			_ui._minimap_drag = false
			surface.get_viewport().set_input_as_handled()
			return
		if event.pressed and _ui.minimap != null and _ui.minimap.get_global_rect().has_point(event.position):
			_ui._minimap_drag = true
			ports._minimap_navigate(event.position)
			surface.get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("battle_cancel") and (_ui.art_sub != "" or _ui.build_menu):
		ports._close_art_sub()
		surface.get_viewport().set_input_as_handled()
		return
	if _navigate_focus(event) or ports._handle_cmd_key(event):
		surface.get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		# 右键落在**不透明 HUD 面板**上时不该变成世界命令（原版点面板什么也不做）
		if mb.pressed and _hud_panel_at(mb.position):
			surface.get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		if mb.pressed and _hud_panel_at(mb.position):
			surface.get_viewport().set_input_as_handled()
		return
	if not mb.pressed and _ui.host.selecting:
		_ui.host.commands.session.unhandled_input(mb)
		surface.get_viewport().set_input_as_handled()
		return
	if not mb.pressed and _ui._hud_panel_capture:
		_ui._hud_panel_capture = false
		surface.get_viewport().set_input_as_handled()
		return
	if not mb.pressed: return
	var hit := _hud_button_at(mb.position)
	if hit.get("pool") == "menu":
		_ui.battle_menu.open()
		surface.get_viewport().set_input_as_handled()
	elif hit.is_empty() and _hud_panel_at(mb.position):
		_ui._hud_panel_capture = true
		surface.get_viewport().set_input_as_handled()

func _navigate_focus(event: InputEvent) -> bool:
	if event.is_action_pressed("battle_confirm"):
		var focused := surface.get_viewport().gui_get_focus_owner()
		if focused is Button and not focused.disabled and _ui.ui_layer.is_ancestor_of(focused):
			_armed_button = weakref(focused)
			_armed_world = _ui.host.world_identity()
			return true
	elif event.is_action_released("battle_confirm") and _armed_button != null:
		var button = _armed_button.get_ref()
		_armed_button = null
		if is_instance_valid(button) and button.has_focus() and button.is_visible_in_tree() and not button.disabled and _armed_world == _ui.host.world_identity():
			button.pressed.emit()
		return true
	for direction in [["left", SIDE_LEFT], ["up", SIDE_TOP], ["right", SIDE_RIGHT], ["down", SIDE_BOTTOM]]:
		if not event.is_action_pressed("battle_focus_" + direction[0]): continue
		var focused := surface.get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and _ui.ui_layer.is_ancestor_of(focused):
			var next := focused.find_valid_focus_neighbor(direction[1])
			if next is Button and not next.disabled: next.grab_focus()
			return true
		for entry in _ui.art_buttons:
			if entry.control.is_visible_in_tree() and not entry.control.disabled:
				entry.control.grab_focus()
				return true
		for button in _ui.cmd_buttons:
			if button.is_visible_in_tree() and not button.disabled:
				button.grab_focus()
				return true
		return false
	return false

func _dismiss_ability_menu(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	if _ui.art_sub == "" or not surface.battle_rect().has_point(event.position): return false
	ports._close_art_sub()
	_ui._hud_panel_capture = true
	surface.get_viewport().set_input_as_handled()
	return true

func _hud_canvas_pos(win_pos: Vector2) -> Vector2:
	# _input 收到的鼠标坐标已由 Godot 转为视口坐标，不可重复逆变换。
	return win_pos

func _hud_button_at(win_pos: Vector2) -> Dictionary:
	var p1: Vector2 = _hud_canvas_pos(win_pos)
	for pair in [[_ui.worker_button,0],[_ui.join_button,1]]:
		if pair[0]!=null and pair[0].visible and pair[0].get_global_rect().has_point(p1):return {"pool":"aux","idx":pair[1],"btn":pair[0]}
	if _ui.banner_tex != null and _ui.banner_tex.get_global_rect().has_point(p1):
		return {"pool": "menu", "idx": 0}
	var pager: Array = [_ui.cmd_prev, _ui.cmd_next, _ui.back_button]
	for i in range(pager.size()):
		var button: Button = pager[i]
		if button != null and button.visible and button.get_global_rect().has_point(p1):
			return {"pool": "pager", "idx": i, "btn": button}
	for i in range(_ui.cmd_buttons.size()):
		var b: Button = _ui.cmd_buttons[i]
		if b.visible and (b.get_global_rect().has_point(p1) or b.get_global_rect().has_point(win_pos)):
			return {"pool": "cmd", "idx": i, "btn": b}
	for i in range(_ui.art_buttons.size()):
		var e: Dictionary = _ui.art_buttons[i]
		var ab: TextureRect = e.btn
		if ab.visible and (ab.get_global_rect().has_point(p1) or ab.get_global_rect().has_point(win_pos)):
			return {"pool": "art", "idx": i, "btn": ab}
	for i in range(_ui.hot_buttons.size()):
		var e: Dictionary = _ui.hot_buttons[i]
		var hb: Button = e.btn
		if hb.visible and (hb.get_global_rect().has_point(p1) or hb.get_global_rect().has_point(win_pos)):
			return {"pool": "hot", "idx": i, "btn": hb}
	return {}

func _hud_panel_at(win_pos: Vector2) -> bool:
	var p1: Vector2 = _hud_canvas_pos(win_pos)
	if _ui.top_bar != null and (_ui.top_bar.get_global_rect().has_point(p1) or _ui.top_bar.get_global_rect().has_point(win_pos)):
		return true
	if _ui.right_panel != null and (_ui.right_panel.get_global_rect().has_point(p1) or _ui.right_panel.get_global_rect().has_point(win_pos)):
		return true
	return false

func _hud_select_hook(want_building: bool) -> void:
	await surface.get_tree().create_timer(0.9).timeout
	var target: Dictionary = {}
	for u in _ui.host.unit_views():
		if not bool(u.alive) or int(u.owner) != int(_ui.host.player_owner):
			continue
		if bool(u.is_building) == want_building:
			target = u
			break
	if target.is_empty():
		print("HUD: --hud-select 没找到目标（building=%s）" % str(want_building))
		return
	var world := Vector2(float(target.ax), float(target.ay) - float(target.h) * 0.5)
	var canvas_pos: Vector2 = surface.get_viewport().get_canvas_transform() * world

	var mm := InputEventMouseMotion.new()
	mm.position = canvas_pos
	mm.global_position = canvas_pos
	Input.parse_input_event(mm)
	await surface.get_tree().process_frame
	_send_click(canvas_pos)
	await surface.get_tree().process_frame
	var read_back: Vector2 = surface.get_global_mouse_position()
	var path: String = "合成鼠标事件"
	if _ui.host.selection_views().is_empty():
		_ui.host.commands.session.select_at(world, false)          # 宿主的真实选择入口（main._input 点击时调的就是它）
		path = "退化：直接调 main._select_click"
	print("HUD: --hud-select 点选「%s」 世界=%s 注入画布=%s 回读世界=%s 偏差=%.1f 路径=%s 已选=%d" % [
		str(target.name), str(world), str(canvas_pos), str(read_back),
		read_back.distance_to(world), path, _ui.host.selection_views().size()])

func _send_click(canvas_pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = canvas_pos
	down.global_position = canvas_pos
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = canvas_pos
	up.global_position = canvas_pos
	Input.parse_input_event(up)

func _hud_click_hook(idx: int, hot: bool) -> void:
	await surface.get_tree().create_timer(1.05).timeout
	var pool_n: int = _ui.hot_buttons.size() if hot else _ui.cmd_buttons.size()
	if idx < 0 or idx >= pool_n:
		print("HUD: --hud-click/%s=%d 越界（按钮池 %d）" % ["hot" if hot else "cmd", idx, pool_n])
		return
	var b: Button = null
	if hot:
		b = (_ui.hot_buttons[idx] as Dictionary).btn
	else:
		b = _ui.cmd_buttons[idx]
	if not b.visible or b.disabled:
		print("HUD: --hud-click=%d 「%s」不可点（visible=%s disabled=%s）" % [idx, b.text, str(b.visible), str(b.disabled)])
		return
	var rect: Rect2 = b.get_global_rect()
	var ctr: Vector2 = rect.get_center()
	var csize: Vector2 = surface.get_viewport_rect().size
	var wsize: Vector2 = Vector2(DisplayServer.window_get_size())
	var win_pos: Vector2 = ctr * (wsize / csize)
	Input.warp_mouse(win_pos)
	await surface.get_tree().process_frame
	await surface.get_tree().process_frame
	var mouse_canvas: Vector2 = surface.get_viewport().get_mouse_position()
	var inside: bool = rect.has_point(mouse_canvas)
	# GUI 角度的旁证：送一次 motion（**窗口坐标**）后问"当前悬停控件是谁"，应当是本按钮
	var mv := InputEventMouseMotion.new()
	mv.position = win_pos
	mv.global_position = win_pos
	Input.parse_input_event(mv)
	await surface.get_tree().process_frame
	var hov: Control = surface.get_viewport().gui_get_hovered_control()
	var hov_name: String = "null"
	if hov != null:
		hov_name = "%s(%s)" % [str(hov.name), hov.get_class()]
	var before_train: int = _ui.host.training_views().size()
	var before_fb: String = str(_ui.host.feedback_text)
	var st_before: String = ports._sel_state_text()
	_ui._click_probe = 0
	b.pressed.connect(_on_click_probe)
	# 真·点击：位置用**窗口坐标**（已实测：GUI 命中测试与 Viewport 预处理都用窗口坐标，
	# 传画布坐标会绕过按钮直接落到世界层，main 收到后 selected.clear()）。
	# 按钮点击由本模块 _input 接管派发（见 _input 的说明）；
	# 合成事件要等一帧才派发，所以这里必须 await 再判定。
	_send_click(win_pos)
	await surface.get_tree().process_frame
	var st_after: String = ports._sel_state_text()
	var probe_n: int = _ui._click_probe
	var fired: bool = (_ui.host.training_views().size() > before_train) or (str(_ui.host.feedback_text) != before_fb) or (st_after != st_before)
	var path: String = "真实点击（本模块 _input 接管）"
	if not fired:
		b.emit_signal("pressed")                     # 兜底：直接触发按钮信号
		st_after = ports._sel_state_text()
		path = "退化：emit_signal(pressed)"
	if b.pressed.is_connected(_on_click_probe):
		b.pressed.disconnect(_on_click_probe)
	print("HUD: --hud-click%s=%d 「%s」 按钮矩形=%s 光标画布=%s 命中=%s gui悬停=%s 路径=%s 按钮信号次数=%d | trainings %d->%d 反馈=\"%s\"->\"%s\" 选中状态 %s -> %s" % [
		"/hot" if hot else "", idx, b.text, str(rect), str(mouse_canvas), str(inside), hov_name, path, probe_n,
		before_train, _ui.host.training_views().size(), before_fb, str(_ui.host.feedback_text), st_before, st_after])

func _on_click_probe() -> void:
	_ui._click_probe += 1
