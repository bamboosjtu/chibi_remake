extends RefCounted
## hud layout: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/hud_layout_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _place_left(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = x
	c.offset_right = x + w
	c.offset_top = y
	c.offset_bottom = y + h

func _pin_right(c: Control, dist_right: float, w: float, top: float, h: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_right = -dist_right
	c.offset_left = -(dist_right + w)
	c.offset_top = top
	c.offset_bottom = top + h

func _pin_bottom_right(c: Control, dist_right: float, w: float, h: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_right = -dist_right
	c.offset_left = -(dist_right + w)
	c.offset_bottom = -6.0 * _ui.ui_scale
	c.offset_top = -(6.0 * _ui.ui_scale + h)

func _apply_metrics() -> void:
	var vp: Vector2 = surface.get_viewport_rect().size
	_ui._vp_cache = vp
	# 原版是 640x480；用「视口高 / 480」做等比刻度，HUD 各元素即按原版像素等比放大。
	var s: float = clampf(minf(vp.y / 480.0, vp.x / 640.0), 0.5, 3.0)
	_ui.ui_scale = s
	if _ui.cam != null: ports.set_zoom()
	ports._layout_cmd_art()
	if _ui._topbar_original:
		ports._apply_metrics_original(vp, s)
		return

	var bar_h: float = 40.0 * s
	var margin: float = 12.0 * s
	var slot_w: float = clampf(vp.x * 0.156, 110.0 * s, 200.0 * s)
	var slot_h: float = 28.0 * s
	var gap: float = 2.0 * s
	var icon_sz: float = 20.0 * s

	_ui.top_bar.offset_bottom = bar_h
	_ui.bar_edge.offset_top = bar_h - 2.0 * s
	_ui.bar_edge.offset_bottom = bar_h

	# 资源槽：1/2 贴左、3/4 贴右，红匾居中（与原版一致：实测 x=24..124 / 125..225 / [匾] / 441..541 / 542..642）
	var slot_top: float = (bar_h - slot_h) * 0.5
	for i in range(_ui.res_slots.size()):
		var e: Dictionary = _ui.res_slots[i]
		var slot: Panel = e.panel
		if i == 0:
			_place_left(slot, margin, slot_top, slot_w, slot_h)
		elif i == 1:
			_place_left(slot, margin + slot_w + gap, slot_top, slot_w, slot_h)
		elif i == 2:
			_pin_right(slot, margin + slot_w + gap, slot_w, slot_top, slot_h)
		else:
			_pin_right(slot, margin, slot_w, slot_top, slot_h)
		var icon: Control = e.icon
		icon.position = Vector2(4.0 * s, (slot_h - icon_sz) * 0.5)
		icon.size = Vector2(icon_sz, icon_sz)
		var val: Label = e.value
		# 原版数字**紧跟图标左对齐**（实测 "1600" 在 x=52..83，槽尾还有 40px 空白）
		val.position = Vector2(4.0 * s + icon_sz + 5.0 * s, 0.0)
		val.size = Vector2(maxf(24.0, slot_w - (9.0 * s + icon_sz + 5.0 * s)), slot_h)

	var bw: float = minf(vp.x * 0.30, 240.0 * s)
	var bh: float = bar_h + 6.0 * s
	_ui.banner.anchor_left = 0.5
	_ui.banner.anchor_right = 0.5
	_ui.banner.anchor_top = 0.0
	_ui.banner.anchor_bottom = 0.0
	_ui.banner.offset_left = -bw * 0.5
	_ui.banner.offset_right = bw * 0.5
	_ui.banner.offset_top = 0.0
	_ui.banner.offset_bottom = bh
	var bsb: StyleBoxFlat = _ui.banner.get_theme_stylebox("panel") as StyleBoxFlat
	if bsb != null:
		bsb.set_corner_radius_all(int(bh * 0.5))

	var pr: float = 12.0                     # ARCH-011：右边缘内缩 12
	var pad: float = 8.0 * s
	var panel_w: float = clampf(vp.x * 0.235, 210.0 * s, 300.0 * s)
	var panel_top: float = bar_h + 8.0 * s
	var panel_bot: float = vp.y - 10.0 * s
	_ui.right_panel.offset_left = -(pr + panel_w)
	_ui.right_panel.offset_right = -pr
	_ui.right_panel.offset_top = panel_top
	_ui.right_panel.offset_bottom = -10.0 * s
	var inner: float = panel_w - 2.0 * pad
	var y: float = panel_top + pad
	var mini_h: float = inner * 0.68
	_pin_right(_ui.minimap_box, pr + pad, inner, y, mini_h)
	_ui.minimap.position = Vector2(2.0 * s, 2.0 * s)
	_ui.minimap.size = Vector2(inner - 4.0 * s, mini_h - 4.0 * s)
	y += mini_h + 6.0 * s

	var sel_h: float = 62.0 * s
	var pw: float = 52.0 * s
	_pin_right(_ui.sel_frame, pr + pad, inner, y, sel_h)
	_ui.sel_portrait.position = Vector2(4.0 * s, 4.0 * s)
	_ui.sel_portrait.size = Vector2(pw, sel_h - 8.0 * s)
	_ui.hp_bg.position = Vector2(4.0 * s, sel_h - 9.0 * s)
	_ui.hp_bg.size = Vector2(pw, 5.0 * s)
	_ui.hp_fill.position = Vector2(1.0, 1.0)
	_ui.hp_fill.size = Vector2(pw - 2.0, 3.0 * s)
	_ui.sel_name.position = Vector2(pw + 10.0 * s, 4.0 * s)
	_ui.sel_name.size = Vector2(inner - pw - 16.0 * s, 26.0 * s)
	_ui.sel_rank.position = Vector2(pw + 10.0 * s, 30.0 * s)
	_ui.sel_rank.size = Vector2(inner - pw - 16.0 * s, sel_h - 34.0 * s)
	y += sel_h + 5.0 * s

	var tr_h: float = 46.0 * s
	_pin_right(_ui.troop_frame, pr + pad, inner, y, tr_h)
	_ui.troop_icon.position = Vector2(4.0 * s, 4.0 * s)
	_ui.troop_icon.size = Vector2(38.0 * s, tr_h - 8.0 * s)
	_ui.officer_portrait.position = _ui.troop_icon.position
	_ui.officer_portrait.size = _ui.troop_icon.size
	_ui.troop_label.position = Vector2(46.0 * s, 3.0 * s)
	_ui.troop_label.size = Vector2(inner - 52.0 * s, tr_h - 6.0 * s)
	y += tr_h + 8.0 * s

	_pin_right(_ui.cmd_title, pr + pad, inner, y, 20.0 * s)
	y += 22.0 * s
	var btn_h: float = 26.0 * s
	var btn_gap: float = 4.0 * s
	_pin_right(_ui.cmd_hint, pr + pad, inner, y, 120.0 * s)
	for i in range(_ui.cmd_buttons.size()):
		var btn: Button = _ui.cmd_buttons[i]
		_pin_right(btn, pr + pad, inner, y + float(i) * (btn_h + btn_gap), btn_h)
	# REQ-005：分页/返回脚行——四列：◀ / 页码 / ▶ / 返回（非翻页或非子菜单时各自隐藏）
	var foot_y: float = y + 6.0 * (btn_h + btn_gap) + 2.0 * s
	var fw: float = (inner - 9.0 * s) * 0.25
	_pin_right(_ui.cmd_prev, pr + pad, fw + 3.0 * s, foot_y, 20.0 * s)
	_pin_right(_ui.cmd_page_label, pr + pad + fw + 4.0 * s, fw * 1.3, foot_y + 2.0 * s, 18.0 * s)
	_pin_right(_ui.cmd_next, pr + pad + fw * 2.0 + 6.0 * s, fw, foot_y, 20.0 * s)
	_pin_right(_ui.back_button, pr + pad + fw * 3.0 + 8.0 * s, inner - fw * 3.0 - 8.0 * s, foot_y, 20.0 * s)
	var stats_top: float = foot_y + 20.0 * s + 6.0 * s
	_pin_right(_ui.panel_label, pr + pad, inner, stats_top, maxf(40.0, panel_bot - pad - stats_top))

	var hx: float = 4.0 * s
	var hw: float = 24.0 * s
	var hh: float = 22.0 * s
	var hgap: float = 3.0 * s
	var hy: float = bar_h + 10.0 * s
	for i in range(_ui.hot_buttons.size()):
		var e2: Dictionary = _ui.hot_buttons[i]
		var hb: Button = e2.btn
		_place_left(hb, hx, hy + float(i) * (hh + hgap), hw, hh)
		var pip: ColorRect = e2.pip
		pip.position = Vector2(2.0 * s, hh * 0.5 - 2.5 * s)
		pip.size = Vector2(5.0 * s, 5.0 * s)

	_pin_bottom_right(_ui.ornament, pr, 120.0 * s, 90.0 * s)

	# REQ-006：布局权威在这里把战场矩形一并写回（顶栏 / 左热键条含边距 / 右面板 / 底栏）
	_ui.hud_metrics.update(vp, bar_h, 28.0 * s, pr + panel_w, 33.0 * s)
	_layout_status_labels(vp, s)
	if _ui.minimap != null:
		_ui.minimap.queue_redraw()
	if _ui.ornament != null:
		_ui.ornament.queue_redraw()

func _decorate_frame(panel: Panel, border: float) -> void:
	var ornament: Control = panel.get_node_or_null("OrnateFrame")
	if ornament == null:
		ornament = load("res://presentation/hud/ornate_frame.gd").new()
		ornament.name = "OrnateFrame"
		panel.add_child(ornament)
		ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.edge = border
	ornament.queue_redraw()

func _layout_status_labels(vp: Vector2, s: float) -> void:
	if _ui.info == null or _ui.status_sub == null:
		return
	var footer_top: float = float(_ui.hud_metrics.battle_rect.end.y)
	var footer_height := maxf(1.0, vp.y - footer_top)
	var x := 28.0 * s
	var width := maxf(100.0, vp.x - 180.0 * s)
	_ui.info.add_theme_font_size_override("font_size", maxi(9, int(12.0 * s)))
	_ui.status_sub.add_theme_font_size_override("font_size", maxi(8, int(9.0 * s)))
	var info_min_height := maxf(1.0, _ui.info.get_combined_minimum_size().y)
	var info_height := minf(maxf(15.0 * s, info_min_height), footer_height)
	var info_y: float = footer_top + (footer_height - info_height) * 0.5
	if _ui.host.show_debug:
		var debug_min_height := maxf(1.0, _ui.status_sub.get_combined_minimum_size().y)
		var debug_height := minf(maxf(13.0 * s, debug_min_height), maxf(1.0, footer_height - info_height))
		var spare := maxf(0.0, footer_height - info_height - debug_height)
		var pad := minf(2.0 * s, spare * 0.25)
		var gap := minf(1.0 * s, maxf(0.0, spare - 2.0 * pad))
		_ui.status_sub.position = Vector2(x, footer_top + pad)
		_ui.status_sub.size = Vector2(width, debug_height)
		info_y = footer_top + pad + debug_height + gap
	else:
		_ui.status_sub.add_theme_font_size_override("font_size", maxi(8, int(9.0 * s)))
	_ui.info.position = Vector2(x, info_y)
	_ui.info.size = Vector2(width, info_height)

func _refresh_metrics() -> void:
	if _ui._vp_cache != surface.get_viewport_rect().size:
		_apply_metrics()

func _draw_ornament() -> void:
	if _ui.ornament == null:
		return
	var w: float = _ui.ornament.size.x
	var h: float = _ui.ornament.size.y
	if w <= 8.0 or h <= 8.0:
		return
	var s: float = _ui.ui_scale
	_ui.ornament.draw_line(Vector2(w * 0.08, h * 0.94), Vector2(w * 0.88, h * 0.12), Color(0.55, 0.5, 0.42), 3.0 * s)
	_ui.ornament.draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.88, h * 0.02), Vector2(w * 1.0, h * 0.10), Vector2(w * 0.84, h * 0.18)]),
		Color(0.85, 0.72, 0.32))
	_ui.ornament.draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.12, h * 0.90), Vector2(w * 0.60, h * 0.26), Vector2(w * 0.74, h * 0.48),
		Vector2(w * 0.34, h * 0.98)]), _ui.c_red)
	_ui.ornament.draw_polyline(PackedVector2Array([
		Vector2(w * 0.12, h * 0.90), Vector2(w * 0.60, h * 0.26), Vector2(w * 0.74, h * 0.48),
		Vector2(w * 0.34, h * 0.98)]), Color(0.9, 0.8, 0.4), 1.5 * s)
