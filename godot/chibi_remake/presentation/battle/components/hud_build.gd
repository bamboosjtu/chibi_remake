extends RefCounted
## hud build: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/hud_build_dependencies.gd").new()
const Textures = preload("res://presentation/battle/runtime_textures.gd")

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _ui_tex(name: String) -> Texture2D:
	if _ui._ui_cache.has(name):
		return _ui._ui_cache[name]
	var t: Texture2D = null
	var p: String = "res://art/full/ui/" + name + ".png"
	t = _ui._skin.texture_for(name)
	if t == null: t = Textures.load_texture(p)
	_ui._ui_cache[name] = t
	return t

func build_ui() -> void:
	_ui.event_view = load("res://presentation/media/event_view.gd").new(_ui.host)
	surface.add_child(_ui.event_view)
	_ui.event_view.media_finished.connect(ports._intro_finished)
	var ui := CanvasLayer.new()
	_ui.ui_layer = ui
	surface.add_child(ui)

	_build_top_bar(ui)          # 四个「图标 + 数字」资源槽 + 顶中红匾
	_build_right_panel(ui)      # 小地图 / 头像框 / 兵力牌 / 命令按钮 / 属性文字
	if _ui._topbar_original:
		_ui.classic_panel = load("res://presentation/hud/battle_hud_panel.gd").new(_ui.host, surface)
		ui.add_child(_ui.classic_panel)
	_ui.battle_menu = load("res://presentation/hud/battle_menu.gd").new(_ui.host)
	surface.add_child(_ui.battle_menu)
	_ui.briefing=preload("res://presentation/hud/mission_briefing.gd").new(_ui.host)
	surface.add_child(_ui.briefing)
	_build_hot_strip(ui)        # 左缘 1..10 热键条
	_build_status(ui)           # 左下状态行（原版「训练完成」的位置）
	_build_ornament(ui)         # 右下红旗矛（自绘装饰）

	_ui.end_label = Label.new()
	# ARCH-011：居中锚定（原来写死 480,300，小窗口会跑出画面）
	_ui.end_label.anchor_left = 0.5
	_ui.end_label.anchor_right = 0.5
	_ui.end_label.anchor_top = 0.5
	_ui.end_label.anchor_bottom = 0.5
	_ui.end_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.end_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.end_label.offset_left = -320.0
	_ui.end_label.offset_right = 320.0
	_ui.end_label.offset_top = -70.0
	_ui.end_label.offset_bottom = 70.0
	_ui.end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.end_label.add_theme_font_size_override("font_size", 96)
	_ui.end_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_ui.end_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
	_ui.end_label.add_theme_constant_override("outline_size", 10)
	_ui.end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.end_label.visible = false
	ui.add_child(_ui.end_label)

	# ARCH-011：右面板钉在**右边缘**（_apply_metrics 里也只按右边缘偏移算）
	ports._apply_metrics()
	print("HUD: 视口=%s UI缩放=%.2f 资源图标=%d/4（0=全部占位）" % [
		str(surface.get_viewport_rect().size), _ui.ui_scale, _ui._icons_real])
	# 截图钩子：合成一次真实点击把单位选上，好让截图里命令面板有内容（默认关，见 _hud_select_hook）
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s == "--hud-select" or s == "--hud-select=mobile":
			ports._hud_select_hook(false)
		elif s == "--hud-select=building":
			ports._hud_select_hook(true)
		elif s.begins_with("--hud-click="):
			ports._hud_click_hook(int(s.substr(12)), false)
		elif s.begins_with("--hud-hot="):
			ports._hud_click_hook(int(s.substr(10)), true)     # 左缘 1..10 热键条

func _mk_panel(parent: Node, bg: Color, border: Color, bw: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(1, int(round(bw))))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", maxi(8, int(round(size))))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _mk_button(parent: Node, size: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.clip_text = true
	b.add_theme_font_size_override("font_size", maxi(8, int(round(size))))
	var n := StyleBoxFlat.new()
	n.bg_color = Color("211b13")
	n.border_color = Color("c69a40")
	n.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = Color("46311c")
	h.border_color = Color(0.85, 0.78, 0.55)
	h.set_border_width_all(1)
	b.add_theme_stylebox_override("hover", h)
	var d := StyleBoxFlat.new()
	d.bg_color = Color("100c08")
	d.border_color = Color(0.4, 0.36, 0.3)
	d.set_border_width_all(1)
	b.add_theme_stylebox_override("pressed", d)
	var o := StyleBoxFlat.new()
	o.bg_color = Color("191713")
	o.border_color = Color("8b6a32")
	o.set_border_width_all(1)
	b.add_theme_stylebox_override("disabled", o)
	b.add_theme_color_override("font_color", _ui.c_text)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color("a99c7c"))
	parent.add_child(b)
	return b

func _build_top_bar(ui: CanvasLayer) -> void:
	var hdr_l := _ui_tex("hud_top_left")
	var hdr_r := _ui_tex("hud_top_right")
	var hdr_tile := _ui_tex("hud_bar_tile")
	if hdr_l != null and hdr_r != null and hdr_tile != null:
		_build_top_bar_original(ui, hdr_l, hdr_r, hdr_tile)
		return
	_ui.top_bar = ColorRect.new()
	_ui.top_bar.color = _ui.c_bar_bg
	_ui.top_bar.anchor_left = 0.0
	_ui.top_bar.anchor_top = 0.0
	_ui.top_bar.anchor_right = 1.0
	_ui.top_bar.anchor_bottom = 0.0
	_ui.top_bar.offset_left = 0.0
	_ui.top_bar.offset_top = 0.0
	_ui.top_bar.offset_right = 0.0
	_ui.top_bar.offset_bottom = 50.0
	_ui.top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.top_bar)

	_ui.bar_edge = ColorRect.new()
	_ui.bar_edge.color = _ui.c_bar_edge
	_ui.bar_edge.anchor_left = 0.0
	_ui.bar_edge.anchor_top = 0.0
	_ui.bar_edge.anchor_right = 1.0
	_ui.bar_edge.anchor_bottom = 0.0
	_ui.bar_edge.offset_left = 0.0
	_ui.bar_edge.offset_right = 0.0
	_ui.bar_edge.offset_top = 48.0
	_ui.bar_edge.offset_bottom = 50.0
	_ui.bar_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.bar_edge)

	var kinds: Array = ["gold", "food", "wood", "stone"]
	var names: Array = ["金", "粮", "木", "铁"]
	_ui.res_slots.clear()
	_ui._icons_real = 0
	for i in range(4):
		var kind: String = str(kinds[i])
		var slot: Panel = _mk_panel(ui, _ui.c_bar_bg, _ui.c_bar_edge, 1.0)
		var icon: Control = null
		var ip: String = ports._res_icon_path(kind)
		if ip != "":
			var tr := TextureRect.new()
			tr.texture = load(ip)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(tr)
			icon = tr
			_ui._icons_real += 1
		else:
			var ph := Panel.new()
			var psb := StyleBoxFlat.new()
			psb.bg_color = Color(0.0, 0.0, 0.16)
			psb.border_color = _ui.c_bar_edge
			psb.set_border_width_all(1)
			ph.add_theme_stylebox_override("panel", psb)
			ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ph)
			var gl := _mk_label(ph, 13.0, _ui.c_gold, HORIZONTAL_ALIGNMENT_CENTER)
			gl.set_anchors_preset(Control.PRESET_FULL_RECT)
			gl.text = str(names[i])
			icon = ph
		var val := _mk_label(slot, 16.0, _ui.c_text, HORIZONTAL_ALIGNMENT_LEFT)
		var src: String = "原版图标" if ip != "" else "占位（写的是汉字，不是原版美术）"
		slot.tooltip_text = "%s —— %s。原版图标在 BMP\\BMP.LWC；本项目 res:// 内没有该图集。" % [str(names[i]), src]
		_ui.res_slots.append({"panel": slot, "icon": icon, "value": val, "kind": kind})

	# 顶中红匾：原版是暗红椭圆 + 更暗的红字（几乎读不出来）。底色照抄，文字改浅金以便阅读。
	_ui.banner = _mk_panel(ui, _ui.c_red, _ui.c_bar_edge, 2.0)
	_ui.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.banner_label = _mk_label(_ui.banner, 17.0, _ui.c_gold, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.banner_label.clip_text = true
	_ui.banner.tooltip_text = "选中对象"
	_ui.banner.visible = false

func _build_top_bar_original(ui: CanvasLayer, tl: Texture2D, tr: Texture2D, tile: Texture2D) -> void:
	_ui._topbar_original = true
	_ui.top_bar = ColorRect.new()
	_ui.top_bar.color = Color(0, 0, 0, 0)          # 只作命中区
	_ui.top_bar.anchor_left = 0.0
	_ui.top_bar.anchor_top = 0.0
	_ui.top_bar.anchor_right = 1.0
	_ui.top_bar.anchor_bottom = 0.0
	_ui.top_bar.offset_left = 0.0
	_ui.top_bar.offset_right = 0.0
	_ui.top_bar.offset_top = 0.0
	_ui.top_bar.offset_bottom = 48.0               # 由 _apply_metrics_original 调整
	_ui.top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.top_bar)
	_ui.bar_tile_tex = TextureRect.new()
	_ui.bar_tile_tex.texture = tile
	_ui.bar_tile_tex.stretch_mode = TextureRect.STRETCH_TILE
	_ui.bar_tile_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.bar_tile_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.bar_tile_tex.tooltip_text = ""
	ui.add_child(_ui.bar_tile_tex)
	_ui.top_left_tex = TextureRect.new()
	_ui.top_left_tex.texture = tl
	_ui.top_left_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.top_left_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.top_left_tex)
	_ui.top_right_tex = TextureRect.new()
	# 旧右簇从 x395 开始，包含红匾最后 15 像素；裁掉重叠部分避免出现第二块红匾。
	var right_atlas := AtlasTexture.new()
	right_atlas.atlas = tr
	var pixel_scale := float(tr.get_width()) / 245.0
	right_atlas.region = Rect2(15 * pixel_scale, 0, 230 * pixel_scale, tr.get_height())
	_ui.top_right_tex.texture = right_atlas
	_ui.top_right_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.top_right_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.top_right_tex)
	# 资源槽独立绘制，解除旧顶栏烘焙图标、重复红匾和数字的绑定。
	_ui.top_left_tex.hide(); _ui.top_right_tex.hide()
	_ui.banner_tex = TextureRect.new()
	_ui.banner_tex.texture = _ui_tex("hud_banner")
	_ui.banner_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.banner_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.banner_tex)
	_ui.res_value_labels.clear()
	_ui.res_slots.clear()
	for kind in ["gold", "food", "wood", "stone"]:
		var slot := _mk_panel(ui, Color("050824"), _ui.c_panel_edge, 1)
		var icon := TextureRect.new()
		icon.texture = _ui_tex("res_" + str(kind))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var l := _mk_label(ui, 19, _ui.c_text, HORIZONTAL_ALIGNMENT_LEFT)
		l.name = "res_" + str(kind)
		_ui.res_value_labels.append(l)
		_ui.res_slots.append({"value": l, "kind": kind, "panel": slot, "icon": icon})
	_ui._icons_real = 4

func _build_right_panel(ui: CanvasLayer) -> void:
	_ui.right_panel = ColorRect.new()
	_ui.right_panel.color = _ui.c_panel_bg
	_ui.right_panel.anchor_left = 1.0
	_ui.right_panel.anchor_right = 1.0
	_ui.right_panel.anchor_top = 0.0
	_ui.right_panel.anchor_bottom = 1.0
	_ui.right_panel.offset_left = -300.0
	_ui.right_panel.offset_right = -12.0        # ARCH-011：钉右边缘
	_ui.right_panel.offset_top = 60.0
	_ui.right_panel.offset_bottom = -10.0
	_ui.right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui.right_panel)

	# 原版素材模式：面板背景用 BMP#40 纹理（缺图时保留平色 c_panel_bg）
	if _ui_tex("hud_right") != null:
		_ui.right_panel.color = Color(0, 0, 0, 0)
		_ui.panel_bg_tex = TextureRect.new()
		_ui.panel_bg_tex.texture = _ui_tex("hud_right")
		_ui.panel_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ui.panel_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.panel_bg_tex.tooltip_text = ""
		ui.add_child(_ui.panel_bg_tex)

	_ui.minimap_box = _mk_panel(ui, _ui.c_mini_bg, Color(0.75, 0.72, 0.65), 1.0)
	_ui.minimap = preload("res://presentation/battle/battle_minimap.gd").new(_ui.host,surface)
	_ui.minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.minimap_box.add_child(_ui.minimap)

	_ui.sel_frame = _mk_panel(ui, Color(0.08, 0.04, 0.02, 0.95), _ui.c_panel_edge, 2.0)
	_ui.sel_portrait = TextureRect.new()
	_ui.sel_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.sel_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ui.sel_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.sel_frame.add_child(_ui.sel_portrait)
	_ui.sel_name = _mk_label(_ui.sel_frame, 17.0, _ui.c_gold, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.sel_rank = _mk_label(_ui.sel_frame, 13.0, _ui.c_text, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.hp_bg = ColorRect.new()
	_ui.hp_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	_ui.hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.sel_frame.add_child(_ui.hp_bg)
	_ui.hp_fill = ColorRect.new()
	_ui.hp_fill.color = Color(0.15, 0.8, 0.2)
	_ui.hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.hp_bg.add_child(_ui.hp_fill)

	_ui.troop_frame = _mk_panel(ui, Color(0.08, 0.04, 0.02, 0.95), _ui.c_panel_edge, 2.0)
	_ui.troop_icon = TextureRect.new()
	_ui.troop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui.troop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ui.troop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.troop_frame.add_child(_ui.troop_icon)
	_ui.troop_label = _mk_label(_ui.troop_frame, 14.0, _ui.c_text, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.troop_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_ui.troop_label.clip_text = false
	_ui.troop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 武将头像沿用现成的 officer_portrait.gd（117 张真实头像，没有头像的身份自动隐藏）
	_ui.officer_portrait = load("res://presentation/hud/officer_portrait.gd").new()
	_ui.troop_frame.add_child(_ui.officer_portrait)

	_ui.cmd_title = _mk_label(ui, 15.0, _ui.c_dim, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.cmd_title.text = "命令"
	_ui.cmd_hint = _mk_label(ui, 13.0, _ui.c_dim, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.cmd_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.cmd_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_ui.cmd_hint.clip_text = false
	_ui.cmd_buttons.clear()
	_ui.cmd_actions.clear()
	_ui.cmd_view.clear()
	for i in range(6):
		var b: Button = _mk_button(ui, 14.0)
		b.pressed.connect(ports._on_cmd.bind(i))
		b.visible = false
		_ui.cmd_buttons.append(b)
		_ui.cmd_actions.append(Callable())
		_ui.cmd_view.append(false)
	# REQ-005：分页器 + 固定返回入口（几何由 _apply_metrics{,_original} 摆放）
	_ui.back_button = _mk_button(ui, 13.0)
	_ui.back_button.text = "返回"
	_ui.back_button.visible = false
	_ui.back_button.pressed.connect(ports._act_close_officer_pick)
	_ui.cmd_prev = _mk_button(ui, 12.0)
	_ui.cmd_prev.text = "◀ 上页"
	_ui.cmd_prev.visible = false
	_ui.cmd_prev.pressed.connect(ports._on_cmd_page.bind(-1))
	_ui.cmd_page_label = _mk_label(ui, 11.0, _ui.c_dim, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.cmd_page_label.visible = false
	_ui.cmd_next = _mk_button(ui, 12.0)
	_ui.cmd_next.text = "下页 ▶"
	_ui.cmd_next.visible = false
	_ui.cmd_next.pressed.connect(ports._on_cmd_page.bind(1))
	_ui.panel_label = _mk_label(ui, 12.0, _ui.c_dim, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.panel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.panel_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_ui.panel_label.clip_text = false

func _build_hot_strip(ui: CanvasLayer) -> void:
	_ui.hot_buttons.clear()
	_ui.hot_actions.clear()
	var st := _ui_tex("hud_left")
	if st != null:
		_ui.left_strip_tex = TextureRect.new()
		_ui.left_strip_tex.texture = st
		_ui.left_strip_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ui.left_strip_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.left_strip_tex.tooltip_text = "原版左缘条（BMP.LWC #36 提取）"
		ui.add_child(_ui.left_strip_tex)
		var sp := _ui_tex("btn_special")
		if sp != null:
			_ui.btn_special_tex = TextureRect.new()
			_ui.btn_special_tex.texture = sp
			_ui.btn_special_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_ui.btn_special_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ui.btn_special_tex.tooltip_text = ""
			ui.add_child(_ui.btn_special_tex)
		var nx := _ui_tex("btn_next")
		if nx != null:
			_ui.btn_next_tex = TextureRect.new()
			_ui.btn_next_tex.texture = nx
			_ui.btn_next_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_ui.btn_next_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ui.btn_next_tex.tooltip_text = ""
			ui.add_child(_ui.btn_next_tex)
	for i in range(10):
		var b: Button = _mk_button(ui, 12.0)
		b.text = "10" if i == 9 else str(i + 1)
		b.pressed.connect(ports._on_hotkey.bind(i))
		var pip := ColorRect.new()
		pip.color = _ui.c_no
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pip)
		var work_badge := Label.new()
		work_badge.text = "建"
		work_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		work_badge.add_theme_color_override("font_color", Color("ffe287"))
		work_badge.hide()
		b.add_child(work_badge)
		_ui.hot_buttons.append({"btn": b, "pip": pip, "work_badge": work_badge})
		_ui.hot_actions.append(Callable())

func _build_status(ui: CanvasLayer) -> void:
	_ui.status_sub = _mk_label(ui, 12.0, _ui.c_dim, HORIZONTAL_ALIGNMENT_LEFT)
	_ui.info = _mk_label(ui, 18.0, _ui.c_gold, HORIZONTAL_ALIGNMENT_LEFT)

func _build_ornament(ui: CanvasLayer) -> void:
	# 底缘条（BMP#31）：铺满全宽的织锦条
	var bt := _ui_tex("hud_bottom")
	if bt != null:
		_ui.bottom_tex = TextureRect.new()
		_ui.bottom_tex.texture = bt
		_ui.bottom_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ui.bottom_tex.stretch_mode = TextureRect.STRETCH_TILE
		_ui.bottom_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.bottom_tex.tooltip_text = "原版底缘条（BMP.LWC #31 提取）"
		ui.add_child(_ui.bottom_tex)
	_ui.ornament = Control.new()
	_ui.ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.ornament.tooltip_text = "自绘装饰（原版这张图在 BMP.LWC，res:// 内没有）"
	_ui.ornament.draw.connect(ports._draw_ornament)
	ui.add_child(_ui.ornament)
