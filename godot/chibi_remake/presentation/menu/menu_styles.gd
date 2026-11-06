extends RefCounted
## menu styles: presentation component.
const UIState = preload("res://presentation/menu/menu_state.gd")
var _ui: UIState
var surface: Control
var ports = preload("res://presentation/menu/ports/menu_styles_dependencies.gd").new()
const ROW_GAP := 3                      # 木条之间的暗缝

func _init(data: UIState, node: Control) -> void:
	_ui = data
	surface = node

func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func _bevel(bg: Color, rim: Color, dark: Color, rim_px: int, drop: int, radius: int, pad: Vector4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = rim
	s.border_width_top = rim_px
	s.border_width_left = rim_px
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(radius)
	if drop > 0:
		s.shadow_color = dark
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, drop)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s

func _highlight(bg: Color, rim: Color, pad: Vector4) -> StyleBoxFlat:
	var s := _flat(bg, rim, 2, 2)
	s.shadow_color = _ui.C_WOOD_DARK
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s

func _sunk(bg: Color, rim: Color, rim_px: int, radius: int, pad: Vector4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = rim
	s.border_width_top = 0
	s.border_width_left = 0
	s.border_width_right = rim_px
	s.border_width_bottom = rim_px
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s

func _build_styles() -> void:
	# 木条：2px 亮上边 + 2px 暗底边；行间 ROW_GAP 的暗缝由面板底色透出来
	var pad := Vector4(12, 4, 10, 4)
	_ui.sb_row_a = _bevel(_ui.C_WOOD_A, _ui.C_WOOD_RIM, _ui.C_WOOD_DARK, 2, 2, 2, pad)
	_ui.sb_row_b = _bevel(_ui.C_WOOD_B, _ui.C_WOOD_RIM, _ui.C_WOOD_DARK, 2, 2, 2, pad)
	_ui.sb_row_hover = _highlight(_ui.C_WOOD_HOVER, _ui.C_WOOD_HOVER_RIM, pad)
	_ui.sb_row_press = _sunk(_ui.C_WOOD_PRESS, _ui.C_WOOD_DARK, 2, 2, Vector4(12, 5, 10, 3))
	# 聚焦 = 悬停同款底色 + 更亮的金边：键盘选中的那一行和鼠标悬停一样显眼
	_ui.sb_row_focus = _highlight(_ui.C_WOOD_HOVER, _ui.C_GOLD_RIM, pad)
	# 金色凸起：3px 亮上边 + 4px 底面阴影 = 立体按钮
	var gpad := Vector4(14, 8, 14, 8)
	_ui.sb_gold = _bevel(_ui.C_GOLD, _ui.C_GOLD_RIM, _ui.C_GOLD_DARK, 3, 4, 3, gpad)
	_ui.sb_gold_hover = _bevel(_ui.C_GOLD_HOVER, _ui.C_GOLD_RIM, _ui.C_GOLD_DARK, 3, 4, 3, gpad)
	_ui.sb_gold_press = _sunk(_ui.C_GOLD_PRESS, _ui.C_GOLD_DARK, 3, 3, Vector4(14, 9, 14, 7))
	_ui.sb_gold_focus = _bevel(_ui.C_GOLD_HOVER, Color("fff6d8"), _ui.C_GOLD_DARK, 3, 4, 3, gpad)

func _wood_frame(sel: bool, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _ui.C_WOOD_A
	s.border_color = _ui.C_ACCENT if sel else _ui.C_WOOD_RIM
	s.set_border_width_all(6 if sel else 4)
	s.set_corner_radius_all(4)
	s.shadow_color = _ui.C_WOOD_DARK
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 6)
	s.set_content_margin_all(pad)
	return s

func _wood_plate() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _ui.C_WOOD_B
	s.border_color = _ui.C_WOOD_RIM
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.shadow_color = _ui.C_WOOD_DARK
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	return s

func _gold_button(text: String, w: float, h: float, fs: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", _ui.C_GOLD_TXT)
	b.add_theme_color_override("font_hover_color", _ui.C_GOLD_TXT)
	b.add_theme_color_override("font_pressed_color", _ui.C_GOLD_TXT)
	b.add_theme_color_override("font_disabled_color", _ui.C_GOLD_TXT)
	b.add_theme_stylebox_override("normal", _ui.sb_gold)
	b.add_theme_stylebox_override("hover", _ui.sb_gold_hover)
	b.add_theme_stylebox_override("pressed", _ui.sb_gold_press)
	b.add_theme_stylebox_override("focus", _ui.sb_gold_focus)
	b.pressed.connect(cb)
	return b
