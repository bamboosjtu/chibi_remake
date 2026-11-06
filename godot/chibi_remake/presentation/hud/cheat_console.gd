extends CanvasLayer
## An information input bar. Key matching belongs to the application controller.
var label: Label
var panel: PanelContainer
var _bounds: Callable

func _init(battle_bounds := Callable()) -> void:
	_bounds = battle_bounds
	layer = 90
	panel = PanelContainer.new()
	panel.position = Vector2(56, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	label = Label.new()
	label.clip_text = true
	label.custom_minimum_size = Vector2(380, 46)
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	hide()

func _process(_delta: float) -> void:
	if visible and _bounds.is_valid():
		var rect: Rect2 = _bounds.call()
		panel.position = rect.position + Vector2(8, 8)

func update_input(value: String) -> void:
	label.text = "信息 > %s_\nEnter 确认 / Esc 关闭" % value
	show()
