extends RefCounted
## level dialog: presentation component.
const UIState = preload("res://presentation/menu/menu_state.gd")
var _ui: UIState
var surface: Control
var ports = preload("res://presentation/menu/ports/level_dialog_dependencies.gd").new()
const CAMPAIGN_TITLE := {"chibic": "曹操线", "chibil": "刘备线"}

const ROW_H := 42                       # 木条行高

const ROW_GAP := 3                      # 木条之间的暗缝

const ARROW_STEP := 135                 # ▲▼ 一次滚 3 行

# ── 调色板（原版是暗石头 + 木 + 金，这里全部按截图取近似色）──


func _init(data: UIState, node: Control) -> void:
	_ui = data
	surface = node

func _build_level_dialog() -> void:
	# 2b：对话框改成几何居中后会压到「赤壁之战」，所以先在整屏盖一层压暗遮罩，
	# 让「压住标题」读起来是有意的模态，而不是排版事故；顺带挡掉漏到菜单按钮的点击。
	_ui.scrim = ColorRect.new()
	_ui.scrim.color = Color(0, 0, 0, 0.55)
	_ui.scrim.anchor_right = 1.0
	_ui.scrim.anchor_bottom = 1.0
	_ui.scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.scrim.visible = false
	surface.add_child(_ui.scrim)

	# 外框：深石面 + 3px 浅色倒角 + 投影
	var frame := StyleBoxFlat.new()
	frame.bg_color = _ui.C_FACE
	frame.border_color = _ui.C_BEVEL
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0, 6)
	frame.set_content_margin_all(6)

	# 摆位（2b 改）：几何居中 —— 四边锚点全 0.5，偏移给 860x580，中心恒等于视口中心。
	# 逻辑坐标恒为 1600x900（canvas_items + expand，1280x720 与 1920x1080 都是 16:9），
	# 所以矩形恒为 (370,160)-(1230,740)。原来 anchor_top=0.39 是「停在标题下面」，
	# 现在居中必然压到标题（标题底 ~251）—— 靠 scrim + 开框时藏标题解决，
	# 自检里 centred=true / title_shown=false / overlap_title=false 三条一起看。
	_ui.level_panel = PanelContainer.new()
	_ui.level_panel.add_theme_stylebox_override("panel", frame)
	_ui.level_panel.anchor_left = 0.5
	_ui.level_panel.anchor_right = 0.5
	_ui.level_panel.anchor_top = 0.5
	_ui.level_panel.anchor_bottom = 0.5
	_ui.level_panel.offset_left = -430.0
	_ui.level_panel.offset_right = 430.0
	_ui.level_panel.offset_top = -290.0
	_ui.level_panel.offset_bottom = 290.0
	_ui.level_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.level_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.level_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 模态：不让点击漏到后面的菜单按钮
	_ui.level_panel.visible = false
	surface.add_child(_ui.level_panel)

	# 内层凹面：2px 暗槽 + 略亮的石面
	var face := StyleBoxFlat.new()
	face.bg_color = _ui.C_FACE_IN
	face.border_color = _ui.C_GROOVE
	face.set_border_width_all(2)
	face.set_corner_radius_all(2)
	face.set_content_margin_all(16)
	_ui.level_face = PanelContainer.new()
	_ui.level_face.add_theme_stylebox_override("panel", face)
	_ui.level_panel.add_child(_ui.level_face)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_ui.level_face.add_child(col)

	# ── 标题行：红方点 + 选择关卡 + 右侧操作提示 ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	var dot := ColorRect.new()
	dot.color = _ui.C_ACCENT
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(dot)

	# 标题文字在 _fill_level_list() 里按已选势力刷成「曹操线 · 选择关卡」
	_ui.level_title = Label.new()
	_ui.level_title.text = "选择关卡"
	_ui.level_title.add_theme_font_size_override("font_size", 26)
	_ui.level_title.add_theme_color_override("font_color", _ui.C_HEAD)
	_ui.level_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_ui.level_title)

	_ui.level_hint = Label.new()
	_ui.level_hint.text = "滚轮 / ▲▼ 翻页 · Esc 返回"
	_ui.level_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui.level_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.level_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.level_hint.add_theme_font_size_override("font_size", 15)
	_ui.level_hint.add_theme_color_override("font_color", _ui.C_HINT)
	_ui.level_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_ui.level_hint)

	# ── 列表 + 右侧 ▲▼ ──
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	_ui.level_scroll = ScrollContainer.new()
	_ui.level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui.level_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_ui.level_scroll.follow_focus = true  # 键盘/方向键换焦点时自动滚到可见
	_ui.level_scroll.custom_minimum_size = Vector2(0, 280)
	_ui.level_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui.level_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_ui.level_scroll)

	_ui.level_list = VBoxContainer.new()
	_ui.level_list.add_theme_constant_override("separation", ROW_GAP)
	_ui.level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui.level_scroll.add_child(_ui.level_list)

	var arrows := VBoxContainer.new()
	arrows.add_theme_constant_override("separation", 8)
	arrows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(arrows)
	arrows.add_child(_make_arrow_button("▲", -ARROW_STEP))
	arrows.add_child(_make_arrow_button("▼", ARROW_STEP))

	# 滚动条也刷成同一套配色（默认主题的亮灰条在石面上很跳）。
	# ScrollBar 的宽度取自 "scroll" 样式盒的 content margin，所以宽度设在这里。
	var bar := _ui.level_scroll.get_v_scroll_bar()
	if bar != null:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.35)
		track.set_corner_radius_all(2)
		track.content_margin_left = 6
		track.content_margin_right = 6
		track.content_margin_top = 0
		track.content_margin_bottom = 0
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("grabber", ports._flat(Color("8d7a4e"), Color("c9b273"), 1, 2))
		bar.add_theme_stylebox_override("grabber_highlight", ports._flat(Color("b39a5f"), Color("e0c98a"), 1, 2))
		bar.add_theme_stylebox_override("grabber_pressed", ports._flat(Color("6f6039"), Color("a08a4e"), 1, 2))

	# ── 底栏：金色凸起「返回」 ──
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)

	_ui.level_back = Button.new()
	_ui.level_back.text = "返回"
	_ui.level_back.custom_minimum_size = Vector2(220, 46)
	_ui.level_back.add_theme_font_size_override("font_size", 22)
	_ui.level_back.add_theme_color_override("font_color", _ui.C_GOLD_TXT)
	_ui.level_back.add_theme_color_override("font_hover_color", _ui.C_GOLD_TXT)
	_ui.level_back.add_theme_color_override("font_pressed_color", _ui.C_GOLD_TXT)
	_ui.level_back.add_theme_color_override("font_disabled_color", _ui.C_GOLD_TXT)
	_ui.level_back.add_theme_stylebox_override("normal", _ui.sb_gold)
	_ui.level_back.add_theme_stylebox_override("hover", _ui.sb_gold_hover)
	_ui.level_back.add_theme_stylebox_override("pressed", _ui.sb_gold_press)
	_ui.level_back.add_theme_stylebox_override("focus", _ui.sb_gold_focus)
	_ui.level_back.pressed.connect(ports._on_back)
	foot.add_child(_ui.level_back)

func _make_arrow_button(glyph: String, delta: int) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(48, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", _ui.C_GOLD_TXT)
	b.add_theme_color_override("font_hover_color", _ui.C_GOLD_TXT)
	b.add_theme_color_override("font_pressed_color", _ui.C_GOLD_TXT)
	b.add_theme_stylebox_override("normal", _ui.sb_gold)
	b.add_theme_stylebox_override("hover", _ui.sb_gold_hover)
	b.add_theme_stylebox_override("pressed", _ui.sb_gold_press)
	b.add_theme_stylebox_override("focus", _ui.sb_gold_focus)
	b.pressed.connect(_scroll_by.bind(delta))
	return b

func _make_level_row(d: Dictionary, chapter: int, alt: bool) -> Button:
	var id := str(d.get("id", ""))
	var level_name := str(d.get("name", id))
	var base: StyleBoxFlat = _ui.sb_row_b if alt else _ui.sb_row_a

	var b := Button.new()
	b.text = "第%d章 %s" % [chapter, level_name]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", _ui.C_WOOD_TXT)
	b.add_theme_color_override("font_hover_color", _ui.C_WOOD_TXT)
	b.add_theme_color_override("font_pressed_color", Color("f2e4c4"))
	b.add_theme_color_override("font_focus_color", _ui.C_WOOD_TXT)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", _ui.sb_row_hover)
	b.add_theme_stylebox_override("pressed", _ui.sb_row_press)
	b.add_theme_stylebox_override("focus", _ui.sb_row_focus)
	b.pressed.connect(ports._on_level.bind(id))
	return b

func _level_key(id: String) -> Array:
	var s := id.to_lower()
	var i := 0
	while i < s.length() and not _is_digit(s[i]):
		i += 1
	var j := i
	while j < s.length() and _is_digit(s[j]):
		j += 1
	return [s.substr(0, i), int(s.substr(i, j - i)), s.substr(j)]

func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"

func _level_before(a: Dictionary, b: Dictionary) -> bool:
	var ka := _level_key(str(a.get("id", "")))
	var kb := _level_key(str(b.get("id", "")))
	if str(ka[0]) != str(kb[0]):
		return str(ka[0]) < str(kb[0])
	if int(ka[1]) != int(kb[1]):
		return int(ka[1]) < int(kb[1])
	return str(ka[2]) < str(kb[2])

func _fill_level_list() -> void:
	# 先摘出再 free：同帧 queue_free 的节点要到帧末才消失，直接 append 会重复堆叠
	for c in _ui.level_list.get_children():
		_ui.level_list.remove_child(c)
		c.queue_free()
	_ui.row_parity = 0
	var arr: Array = []
	var levels: Array = Game.list_levels()
	for lv in levels:
		var d: Dictionary = lv
		var id := str(d.get("id", "")).to_lower()
		if _ui.campaign != "" and not id.begins_with(_ui.campaign):
			continue
		arr.append(d)
	arr.sort_custom(_level_before)
	if _ui.level_title != null:
		_ui.level_title.text = _campaign_title_text()
	_add_rows(arr)

func _add_rows(arr: Array) -> void:
	var n := 0
	for lv in arr:
		var d: Dictionary = lv
		n += 1
		_ui.level_list.add_child(_make_level_row(d, n, _ui.row_parity % 2 == 1))
		_ui.row_parity += 1

func _campaign_title_text() -> String:
	var t := str(CAMPAIGN_TITLE.get(_ui.campaign, ""))
	if t == "":
		return "选择关卡"
	return "%s · 选择关卡" % t

func _first_row() -> Button:
	for c in _ui.level_list.get_children():
		if c is Button:
			return c
	return null

func _scroll_by(delta: int) -> void:
	if _ui.level_scroll == null:
		return
	var bar := _ui.level_scroll.get_v_scroll_bar()
	if bar == null:
		return
	var hi := maxi(0, int(bar.max_value - bar.page))
	bar.value = float(clampi(int(bar.value) + delta, 0, hi))
	print("LEVELS scrollby: delta=%d got=%d max=%d page=%.0f" % [delta, int(bar.value), hi, bar.page])

func _scroll_to(pos: int) -> void:
	if _ui.level_scroll == null:
		return
	var bar := _ui.level_scroll.get_v_scroll_bar()
	if bar == null:
		return
	var hi := maxi(0, int(bar.max_value - bar.page))
	bar.value = float(clampi(pos, 0, hi))
	print("LEVELS scroll: want=%d got=%d max=%d page=%.0f" % [pos, int(bar.value), hi, bar.page])

func _focus_row(n: int) -> void:
	var rows: Array = []
	for c in _ui.level_list.get_children():
		if c is Button:
			rows.append(c)
	if rows.is_empty():
		return
	var idx := clampi(n, 0, rows.size() - 1)
	var b: Button = rows[idx]
	b.grab_focus()
	print("LEVELS focus: row=%d/%d text=%s" % [idx, rows.size() - 1, b.text])

func _arrow_wiring(glyph: String) -> String:
	var found: Button = null
	var stack: Array = [_ui.level_panel]
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		for ch in node.get_children():
			if ch is Button and (ch as Button).text == glyph:
				found = ch
				break
			stack.append(ch)
	if found == null:
		return "%s=<missing>" % glyph
	var desc := ""
	for cn in found.pressed.get_connections():
		var cb: Callable = cn["callable"]
		desc += "%s%s " % [str(cb.get_method()), str(cb.get_bound_arguments())]
	return "%s->%s" % [glyph, desc.strip_edges()]
