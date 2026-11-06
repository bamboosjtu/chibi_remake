extends RefCounted
## automation driver: presentation component.
const UIState = preload("res://presentation/menu/menu_state.gd")
var _ui: UIState
var surface: Control
var ports = preload("res://presentation/menu/ports/automation_driver_dependencies.gd").new()
const CAMPAIGN_CAO := "chibic"             # 左格：曹操（关卡 id 前缀也是它）

const CAMPAIGN_LIU := "chibil"             # 右格：刘备

const ROW_H := 42                       # 木条行高

const ROW_GAP := 3                      # 木条之间的暗缝

const ROW_STEP := ROW_H + ROW_GAP

func _init(data: UIState, node: Control) -> void:
	_ui = data
	surface = node

func _report_scroll_state() -> void:
	var bar := _ui.level_scroll.get_v_scroll_bar()
	if bar == null:
		return
	var focus_owner: Control = surface.get_viewport().gui_get_focus_owner()
	var fname := "<none>"
	if focus_owner != null:
		fname = str(focus_owner.name)
		if focus_owner is Button:
			fname += ":" + (focus_owner as Button).text
	print("LEVELS state: scroll=%.0f content=%.0f page=%.0f focus=%s" % [
		bar.value, bar.max_value, bar.page, fname,
	])

func _report_level_dialog() -> void:
	var rows := 0
	var sections := 0
	for c in _ui.level_list.get_children():
		if c is Button:
			rows += 1
		else:
			sections += 1
	var content_h := 0.0
	var max_scroll := 0
	var bar := _ui.level_scroll.get_v_scroll_bar()
	if bar != null:
		content_h = bar.max_value
		max_scroll = maxi(0, int(bar.max_value - bar.page))
	var pr := _ui.level_panel.get_global_rect()
	# 2b 的自检字段：centred = 面板中心是否等于视口中心（±1px）；
	# title_shown = 开对话框时标题有没有被压掉；overlap_title 只在标题真的可见时才算重叠，
	# 标题被藏起来就不存在「视觉打架」。scrim = 压暗遮罩有没有开。
	var vp := surface.get_viewport_rect().size
	var centred := absf(pr.get_center().x - vp.x * 0.5) <= 1.0 and absf(pr.get_center().y - vp.y * 0.5) <= 1.0
	var title_shown := _ui.title_label != null and _ui.title_label.visible
	var title_bottom := -1.0
	if title_shown:
		title_bottom = _ui.title_label.get_global_rect().end.y
	var overlap := title_shown and pr.position.y < title_bottom
	print("LEVELS: rows=%d sections=%d campaign=%s total_levels=%d vp=%.0fx%.0f view_h=%.0f visible_rows=%.1f content_h=%.0f max_scroll=%d panel=(%.0f,%.0f %.0fx%.0f) centred=%s title_shown=%s scrim=%s title_bottom=%.0f overlap_title=%s" % [
		rows, sections, _ui.campaign, Game.list_levels().size(), vp.x, vp.y,
		_ui.level_scroll.size.y, _ui.level_scroll.size.y / float(ROW_STEP),
		content_h, max_scroll, pr.position.x, pr.position.y, pr.size.x, pr.size.y,
		str(centred), str(title_shown), str(_ui.scrim != null and _ui.scrim.visible),
		title_bottom, str(overlap),
	])
	# 逐行把「第N章 关名」摊出来，方便机器核对章号与过滤结果（2c）。
	var chapter_txt := ""
	for c in _ui.level_list.get_children():
		if c is Button:
			if chapter_txt != "":
				chapter_txt += " | "
			chapter_txt += (c as Button).text
	print("LEVELS chapters: %s" % chapter_txt)
	# 逐行把「行号（0 基，跟 --focus 的取值一致）↔ 关卡 id」摊出来 —— 截图逐关扫的
	# 文件命名与焦点行核对都靠它，不在输出里靠猜。
	var rowids_arr: Array = []
	for c in _ui.level_list.get_children():
		if c is Button:
			var rid := ""
			for cn in (c as Button).pressed.get_connections():
				var cb: Callable = cn["callable"]
				var bound: Array = cb.get_bound_arguments()
				if bound.size() > 0:
					rid = str(bound[0])
					break
			rowids_arr.append(rid)
	print("LEVELS rowids: %s" % ",".join(rowids_arr))
	# 悬停/聚焦到底有没有接上：把第一行解析出来的三种样式底色打出来（不一致才算接上）
	var first := ports._first_row()
	if first != null:
		var n := first.get_theme_stylebox("normal") as StyleBoxFlat
		var h := first.get_theme_stylebox("hover") as StyleBoxFlat
		var f := first.get_theme_stylebox("focus") as StyleBoxFlat
		print("LEVELS style: row=%s normal=%s hover=%s focus=%s hover_differs=%s" % [
			first.text, str(n.bg_color), str(h.bg_color), str(f.bg_color),
			str(n.bg_color != h.bg_color),
		])
	# ▲▼ 有没有真的接到 _scroll_by（把连接和绑定的像素步长打出来）
	print("LEVELS arrows: %s / %s" % [ports._arrow_wiring("▲"), ports._arrow_wiring("▼")])

func _report_campaign_dialog() -> void:
	if _ui.campaign_panel == null:
		print("CAMPAIGN: panel=<missing>")
		return
	var pr := _ui.campaign_panel.get_global_rect()
	var vp := surface.get_viewport_rect().size
	var centred := absf(pr.get_center().x - vp.x * 0.5) <= 1.0 and absf(pr.get_center().y - vp.y * 0.5) <= 1.0
	var slots_txt := ""
	for s in _ui.campaign_slots:
		var r: Rect2 = (s as Control).get_global_rect()
		if slots_txt != "":
			slots_txt += " "
		slots_txt += "(%.0f,%.0f %.0fx%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]
	var arrow_shown := _ui.campaign_cursor != null and _ui.campaign_cursor.visible
	var ap := Vector2.ZERO
	if _ui.campaign_cursor != null:
		ap = _ui.campaign_cursor.position
	print("CAMPAIGN: slots=%d choice=%s visible=%s vp=%.0fx%.0f panel=(%.0f,%.0f %.0fx%.0f) centred=%s scrim=%s title_shown=%s" % [
		_ui.campaign_slots.size(), _ui.campaign_choice, str(_ui.campaign_panel.visible), vp.x, vp.y,
		pr.position.x, pr.position.y, pr.size.x, pr.size.y,
		str(centred), str(_ui.scrim != null and _ui.scrim.visible),
		str(_ui.title_label != null and _ui.title_label.visible),
	])
	print("CAMPAIGN slot_rects: %s" % slots_txt)
	print("CAMPAIGN arrow: visible=%s at=(%.0f,%.0f)" % [str(arrow_shown), ap.x, ap.y])
	print("CAMPAIGN portraits: %s %s" % [ports._portrait_status(CAMPAIGN_CAO), ports._portrait_status(CAMPAIGN_LIU)])

func _count_rows() -> int:
	var n := 0
	for c in _ui.level_list.get_children():
		if c is Button:
			n += 1
	return n

func _push_key(code: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	surface.get_viewport().push_input(down)
	await surface.get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	surface.get_viewport().push_input(up)
	await surface.get_tree().process_frame

func _run_keytest() -> void:
	if not _ui.campaign_panel.visible:
		ports._on_start()
	await surface.get_tree().create_timer(0.4).timeout
	_report_campaign_dialog()
	var b0: Button = _ui.main_buttons[0]
	await _push_key(KEY_LEFT)
	print("KEYTEST left: choice=%s visible=%s" % [_ui.campaign_choice, str(_ui.campaign_panel.visible)])
	await _push_key(KEY_RIGHT)
	print("KEYTEST right: choice=%s" % _ui.campaign_choice)
	await _push_key(KEY_D)
	print("KEYTEST d: choice=%s (应=chibil)" % _ui.campaign_choice)
	await _push_key(KEY_A)
	print("KEYTEST a: choice=%s (应=chibic)" % _ui.campaign_choice)
	await _push_key(KEY_ENTER)
	print("KEYTEST enter: campaign=%s campaign_visible=%s level_visible=%s rows=%d scrim=%s" % [
		_ui.campaign, str(_ui.campaign_panel.visible), str(_ui.level_panel.visible), _count_rows(),
		str(_ui.scrim != null and _ui.scrim.visible),
	])
	await _push_key(KEY_ESCAPE)
	print("KEYTEST esc-level: level_visible=%s scrim=%s title_shown=%s main_button0=%s" % [
		str(_ui.level_panel.visible), str(_ui.scrim != null and _ui.scrim.visible),
		str(_ui.title_label != null and _ui.title_label.visible), str(b0.visible),
	])
	ports._on_start()
	await surface.get_tree().process_frame
	await _push_key(KEY_ESCAPE)
	print("KEYTEST esc-campaign: campaign_visible=%s scrim=%s main_button0=%s" % [
		str(_ui.campaign_panel.visible), str(_ui.scrim != null and _ui.scrim.visible), str(b0.visible),
	])

func _mouse_click_point_for(target: String) -> Dictionary:
	const UNKNOWN := {"kind": "", "label": "", "point": Vector2(-1, -1)}
	var t := target.strip_edges().to_lower()
	if t == "slotl" or t == "slot0" or t == "cao" or t == "left":
		if _ui.campaign_slots.size() < 1 or _ui.campaign_panel == null or not _ui.campaign_panel.visible:
			return UNKNOWN
		var r0: Rect2 = (_ui.campaign_slots[0] as Control).get_global_rect()
		return {"kind": "slot", "camp": CAMPAIGN_CAO, "label": "slotL", "point": r0.get_center()}
	if t == "slotr" or t == "slot1" or t == "liu" or t == "right":
		if _ui.campaign_slots.size() < 2 or _ui.campaign_panel == null or not _ui.campaign_panel.visible:
			return UNKNOWN
		var r1: Rect2 = (_ui.campaign_slots[1] as Control).get_global_rect()
		return {"kind": "slot", "camp": CAMPAIGN_LIU, "label": "slotR", "point": r1.get_center()}
	if t == "outside":
		return {"kind": "outside", "label": "outside", "point": Vector2(80.0, 80.0)}
	if t == "confirm" or t == "ok" or t == "确定":
		if _ui.campaign_panel == null or not _ui.campaign_panel.visible:
			return UNKNOWN
		var gb1: Button = _find_gold_button("确定")
		if gb1 == null:
			return UNKNOWN
		return {"kind": "gold", "label": "确定", "point": (gb1 as Control).get_global_rect().get_center()}
	if t == "cancel" or t == "back" or t == "取消":
		if _ui.campaign_panel == null or not _ui.campaign_panel.visible:
			return UNKNOWN
		var gb2: Button = _find_gold_button("取消")
		if gb2 == null:
			return UNKNOWN
		return {"kind": "gold", "label": "取消", "point": (gb2 as Control).get_global_rect().get_center()}
	var pos := Vector2(-1.0, -1.0)
	var ok := false
	if "," in t:
		var parts := t.split(",")
		if parts.size() == 2:
			var px := parts[0].strip_edges()
			var py := parts[1].strip_edges()
			if px.is_valid_float() and py.is_valid_float() and float(px) >= 0.0 and float(py) >= 0.0:
				pos = Vector2(float(px), float(py))
				ok = true
	if not ok:
		return UNKNOWN
	return {"kind": "point", "label": "%s,%s" % [str(int(pos.x + 0.5)), str(int(pos.y + 0.5))], "point": pos}

func _find_gold_button(text: String) -> Button:
	if _ui.campaign_panel == null:
		return null
	var stack: Array = [_ui.campaign_panel]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Button and (nd as Button).text == text:
			return nd
		for ch in nd.get_children():
			stack.append(ch)
	return null

func _push_mouse_click(point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	surface.get_viewport().push_input(down, true)
	await surface.get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	surface.get_viewport().push_input(up, true)
	await surface.get_tree().process_frame

func _run_mouse_matrix() -> void:
	if _ui.campaign_panel == null:
		print("MOUSECLICK: target=unspecified result=error=no-panel ok=false")
		return
	if not _ui.campaign_panel.visible:
		ports._on_start()
	await surface.get_tree().create_timer(0.4).timeout
	_report_campaign_dialog()
	var b0: Button = _ui.main_buttons[0] if _ui.main_buttons.size() > 0 else null
	# 1) 点右格（默认高亮是曹操）→ 换边到刘备；同格再点一遍 = 幂等重选，不开列表
	await _mouse_click_slot(1)
	await _mouse_click_slot(1)
	# 2) 点左格 → 回曹操
	await _mouse_click_slot(0)
	# 3) 左格 + Enter：应该和键盘「← + Enter」同一结局 —— 确定曹操、开列表
	await _push_key(KEY_ENTER)
	print("MOUSECLICK: target=enter point=key result=%s campaign=%s campaign_visible=%s level_visible=%s rows=%d ok=%s" % [
		"confirmed" if _ui.level_panel.visible else "not-confirmed",
		_ui.campaign, str(_ui.campaign_panel.visible), str(_ui.level_panel.visible), _count_rows(),
		str(_ui.level_panel.visible and _ui.campaign == _ui.campaign_choice and not _ui.campaign_panel.visible),
	])
	# 4) Esc 收掉列表 → 重开势力框 → 点面板外固定点：选择不能变，框也不能关
	await _push_key(KEY_ESCAPE)
	ports._on_start()
	await surface.get_tree().process_frame
	await surface.get_tree().process_frame
	var out_choice := _ui.campaign_choice
	await _push_mouse_click(Vector2(80.0, 80.0))
	print("MOUSECLICK: target=outside point=(80,80) result=%s changed=%s campaign_visible=%s level_visible=%s ok=%s" % [
		_ui.campaign_choice, str(out_choice != _ui.campaign_choice),
		str(_ui.campaign_panel.visible), str(_ui.level_panel.visible),
		str(_ui.campaign_choice == out_choice and _ui.campaign_panel.visible and not _ui.level_panel.visible),
	])
	# 5) 点金凸「确定」→ 鼠标也能确认（和第 3 步的 Enter 同结局）
	await _mouse_click_slot(2)
	# 6) 最后收尾：重新开一下势力框再点「取消」，验证「取消」这个金凸也是活的
	ports._on_back()
	await surface.get_tree().process_frame
	ports._on_start()
	await surface.get_tree().process_frame
	await _mouse_click_slot(3)
	print("MOUSETEST done: campaign=%s choice=%s level_visible=%s b0=%s" % [
		_ui.campaign, _ui.campaign_choice, str(_ui.level_panel.visible), str(b0.visible if b0 != null else false),
	])

func _mouse_click_slot(idx: int) -> void:
	var t := ("slot%s" % ("L" if idx == 0 else "R")) if idx < 2 else ("确定" if idx == 2 else "取消")
	var info := _mouse_click_point_for(t)
	var kind := str(info.get("kind", ""))
	if kind != "slot" and kind != "gold":
		print("MOUSECLICK: target=%s result=error=unresolvable ok=false" % t)
		return
	var p: Vector2 = info.get("point", Vector2(-1.0, -1.0))
	var before := _ui.campaign_choice
	await _push_mouse_click(p)
	if kind == "gold":
		# 「确定」：收掉框开列表；「取消」：两个模态都关、回主菜单
		if str(info.get("label", "")) == "取消":
			print("MOUSECLICK: target=取消 point=(%.0f,%.0f) result=cancelled campaign=%s campaign_visible=%s level_visible=%s main_button0=%s ok=%s" % [
				p.x, p.y, _ui.campaign, str(_ui.campaign_panel.visible), str(_ui.level_panel.visible),
				str(_ui.main_buttons[0].visible if _ui.main_buttons.size() > 0 else "-"),
				str(_ui.campaign_panel.visible == false and _ui.level_panel.visible == false),
			])
		else:
			print("MOUSECLICK: target=确定 point=(%.0f,%.0f) result=confirm campaign=%s campaign_visible=%s level_visible=%s rows=%d ok=%s" % [
				p.x, p.y, _ui.campaign, str(_ui.campaign_panel.visible), str(_ui.level_panel.visible), _count_rows(),
				str(_ui.campaign_panel.visible == false and _ui.level_panel.visible and _ui.campaign == _ui.campaign_choice),
			])
	else:
		print("MOUSECLICK: target=%s point=(%.0f,%.0f) result=%s changed=%s campaign_visible=%s level_visible=%s ok=%s" % [
			t, p.x, p.y, _ui.campaign_choice, str(_ui.campaign_choice != before),
			str(_ui.campaign_panel.visible), str(_ui.level_panel.visible),
			str(_ui.campaign_choice == str(info.get("camp", "")) and _ui.campaign_panel.visible),
		])

func _run_mouse_click(target: String) -> void:
	if target == "unspecified":
		print("MOUSECLICK: target=unspecified result=error=missing-value ok=false")
		return
	if _ui.campaign_panel == null:
		print("MOUSECLICK: target=%s result=error=no-panel ok=false" % target)
		return
	if not _ui.campaign_panel.visible:
		ports._on_start()
	# 无论框是不是这条命令刚开的，都要等布局稳定再取格子矩形 ——
	# 不然 get_global_rect 可能还是排版中的中间值，点会落在错位的地方。
	await surface.get_tree().create_timer(0.4).timeout
	var info := _mouse_click_point_for(target)
	var kind := str(info.get("kind", ""))
	if kind != "slot" and kind != "outside" and kind != "point" and kind != "gold":
		print("MOUSECLICK: target=%s result=error=unresolvable ok=false" % target)
		return
	var p: Vector2 = info.get("point", Vector2(-1.0, -1.0))
	var label := str(info.get("label", target))
	var before := _ui.campaign_choice
	await _push_mouse_click(p)
	var confirmable := _ui.level_panel.visible
	# ok 判据按 target 种类分派：slot = 选中了它自己的那条线且框还开着；
	# outside = 点了不该有反应 → 选择不变、框还开着；point = 只要事件投递成功就算 ok（状态行如实报）。
	var ok := true
	if kind == "slot":
		ok = _ui.campaign_choice == str(info.get("camp", "")) and _ui.campaign_panel.visible
	elif kind == "outside":
		ok = _ui.campaign_choice == before and _ui.campaign_panel.visible and not _ui.level_panel.visible
	if kind == "gold":
		# 点「确定」/ 「取消」：一个开列表，一个两个模态都关、回主菜单
		print("MOUSECLICK: target=%s point=(%.0f,%.0f) result=%s campaign=%s campaign_visible=%s level_visible=%s main_button0=%s ok=%s" % [
			label, p.x, p.y,
			("confirm" if label == "确定" else "cancelled"), _ui.campaign,
			str(_ui.campaign_panel.visible), str(_ui.level_panel.visible),
			str(_ui.main_buttons[0].visible if _ui.main_buttons.size() > 0 else false),
			str((label == "确定" and _ui.campaign_panel.visible == false and confirmable) or
				(label == "取消" and _ui.campaign_panel.visible == false and confirmable == false)),
		])
	else:
		print("MOUSECLICK: target=%s point=(%.0f,%.0f) result=%s changed=%s campaign_visible=%s level_visible=%s ok=%s" % [
			label, p.x, p.y, _ui.campaign_choice, str(_ui.campaign_choice != before),
			str(_ui.campaign_panel.visible), str(confirmable), str(ok),
		])
