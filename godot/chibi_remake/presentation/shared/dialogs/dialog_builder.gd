extends RefCounted
## Shared framing for the campaign and level dialogs.
static func add_frame(surface: Control, panel: PanelContainer, face: PanelContainer, ui: RefCounted, half_size: Vector2) -> VBoxContainer:
	var frame := StyleBoxFlat.new()
	frame.bg_color = ui.C_FACE
	frame.border_color = ui.C_BEVEL
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0, 6)
	frame.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", frame)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -half_size.x
	panel.offset_right = half_size.x
	panel.offset_top = -half_size.y
	panel.offset_bottom = half_size.y
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	surface.add_child(panel)

	var inset := StyleBoxFlat.new()
	inset.bg_color = ui.C_FACE_IN
	inset.border_color = ui.C_GROOVE
	inset.set_border_width_all(2)
	inset.set_corner_radius_all(2)
	inset.set_content_margin_all(16)
	face.add_theme_stylebox_override("panel", inset)
	panel.add_child(face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	face.add_child(column)
	return column
