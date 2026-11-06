extends RefCounted
## legacy layout: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/legacy_layout_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _apply_metrics_original(vp: Vector2, s: float) -> void:
	var bar_h := 40.0 * s
	var side := 144.0 * s
	var bottom := 33.0 * s
	var left := 32.0 * s
	var x := vp.x - side + 6.0 * s
	var inner := side - 12.0 * s
	var mini_h := 100.0 * s
	var portrait_y := bar_h + mini_h + 10.0 * s
	var command_y := vp.y - bottom - 123.5 * s
	_ui.top_bar.offset_bottom = bar_h
	_ui.bar_tile_tex.hide(); _ui.top_left_tex.hide(); _ui.top_right_tex.hide()
	if _ui.left_strip_tex != null: _ui.left_strip_tex.hide()
	if _ui.panel_bg_tex != null: _ui.panel_bg_tex.hide()
	if _ui.bottom_tex != null: _ui.bottom_tex.hide()
	if _ui.chrome == null:
		_ui.chrome = load("res://presentation/hud/battle_chrome.gd").new()
		_ui.ui_layer.add_child(_ui.chrome)
		_ui.ui_layer.move_child(_ui.chrome, 0)
	_ui.hud_metrics.update(vp, bar_h, left, side, bottom)
	_ui.chrome.arrange(vp, _ui.hud_metrics.battle_rect, s)
	if _ui.banner_tex != null:
		ports._place_left(_ui.banner_tex, (vp.x - 180 * s) * 0.5, 3 * s, 180 * s, 33 * s)
	var slot_w := minf(104 * s, vp.x * 0.125)
	var positions := [14.0 * s, 18.0 * s + slot_w, vp.x - 18.0 * s - 2 * slot_w, vp.x - 14.0 * s - slot_w]
	for i in range(_ui.res_slots.size()):
		ports._place_left(_ui.res_slots[i].panel, positions[i], 9 * s, slot_w, 25 * s)
		_ui.res_slots[i].icon.position = Vector2(4, 3) * s
		_ui.res_slots[i].icon.size = Vector2(23, 19) * s
		ports._place_left(_ui.res_value_labels[i], positions[i] + 32 * s, 9 * s, slot_w - 36 * s, 25 * s)
		_ui.res_value_labels[i].add_theme_font_size_override("font_size", maxi(10, int(13 * s)))
		ports._decorate_frame(_ui.res_slots[i].panel, 2.5 * s)
	for i in range(_ui.hot_buttons.size()):
		var entry: Dictionary = _ui.hot_buttons[i]
		ports._place_left(entry.btn, 4 * s, bar_h + (32 + 25 * i) * s, 24 * s, 22 * s)
		entry.btn.add_theme_font_size_override("font_size", maxi(8, int(11 * s)))
		entry.pip.hide()
	if _ui.btn_special_tex != null: ports._place_left(_ui.btn_special_tex, 4 * s, bar_h + 6 * s, 24 * s, 20 * s)
	if _ui.btn_next_tex != null: ports._place_left(_ui.btn_next_tex, 4 * s, bar_h + 284 * s, 24 * s, 20 * s)
	_ui.right_panel.anchor_bottom = 0
	_ui.right_panel.offset_left = -side; _ui.right_panel.offset_right = 0
	_ui.right_panel.offset_top = bar_h; _ui.right_panel.offset_bottom = vp.y - bottom
	ports._pin_right(_ui.minimap_box, 6 * s, inner, bar_h + 5 * s, mini_h)
	_ui.minimap.position = Vector2(4, 4) * s
	_ui.minimap.size = Vector2(inner - 8 * s, mini_h - 8 * s)
	ports._decorate_frame(_ui.minimap_box, 4 * s)
	if _ui.classic_panel != null:
		_ui.classic_panel.position = Vector2(x, portrait_y)
		_ui.classic_panel.set_ui_scale(s)
	_ui.sel_frame.hide(); _ui.troop_frame.hide(); _ui.panel_label.hide(); _ui.cmd_title.hide(); _ui.cmd_hint.hide()
	for i in range(_ui.cmd_buttons.size()):
		ports._place_left(_ui.cmd_buttons[i], x + (i % 2) * (inner + 2 * s) / 2, command_y + (i / 2) * 28 * s, (inner - 2 * s) / 2, 26 * s)
		_ui.cmd_buttons[i].add_theme_font_size_override("font_size", maxi(8, int(10 * s)))
	ports._place_left(_ui.cmd_prev, x, command_y + 86 * s, 41 * s, 22 * s)
	ports._place_left(_ui.cmd_next, x + 45 * s, command_y + 86 * s, 41 * s, 22 * s)
	ports._place_left(_ui.back_button, x + 90 * s, command_y + 86 * s, 42 * s, 22 * s)
	ports._place_left(_ui.cmd_page_label, x, command_y + 110 * s, inner, 12 * s)
	_ui.status_sub.visible = _ui.host.show_debug
	ports._layout_status_labels(vp, s)
	_ui.ornament.hide()
	ports._layout_cmd_art()
	if _ui.cam != null: ports.clamp_camera()
	if _ui.minimap != null: _ui.minimap.queue_redraw()
