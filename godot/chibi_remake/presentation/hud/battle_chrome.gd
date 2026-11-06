extends Control
## 装饰仅沿实际控件的边界排布；不把整张带分隔线的面板拉伸为布局。
const Textures = preload("res://presentation/battle/runtime_textures.gd")
const Frame = preload("res://presentation/hud/ornate_frame.gd")
var texture: Texture2D
var relief: Texture2D
var bands: Texture2D
var area := Rect2()
var ui_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = Textures.load_texture("res://art/full/ui/hud_right-redraw-v2.png")
	relief = Textures.load_texture("res://art/full/ui/hud-ornate-frame-v3.png")
	bands = Textures.load_texture("res://art/full/ui/hud-horizontal-bands-v4.png")

func arrange(viewport_size: Vector2, battlefield: Rect2, s: float) -> void:
	size = viewport_size; area = battlefield; ui_scale = s
	queue_redraw()

func _frame(rect: Rect2, filled: bool = true) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	var edge := minf(5.0 * ui_scale, minf(rect.size.x, rect.size.y) * 0.3)
	if filled:
		draw_texture_rect_region(texture, rect, Rect2(90, 550, 590, 820), Color(0.38, 0.30, 0.22))
	Frame.paint(self, relief, rect, 6.0 * ui_scale)

func _header() -> void:
	var h := area.position.y
	draw_rect(Rect2(0, 0, size.x, h), Color("261309"))
	# 先铺满木雕再叠透明匾额，透明角落才能透出雕花，而不是底色矩形。
	_band(Rect2(0, 0, size.x, h), Rect2(0, 80, 1983, 286))
	draw_line(Vector2(0, 3 * ui_scale), Vector2(size.x, 3 * ui_scale), Color("d6ab40"), 2 * ui_scale)
	draw_line(Vector2(0, h - 2 * ui_scale), Vector2(size.x, h - 2 * ui_scale), Color("d6ab40"), 2 * ui_scale)

## 按高度等比缩放，再横向重复；末块仅裁切，不把龙身压扁铺满整屏。
func _band(destination: Rect2, source: Rect2) -> void:
	if bands == null or destination.size.y <= 0: return
	var scale_factor := destination.size.y / source.size.y
	var tile_width := source.size.x * scale_factor
	var x := destination.position.x
	while x < destination.end.x:
		var width := minf(tile_width, destination.end.x - x)
		draw_texture_rect_region(bands, Rect2(x, destination.position.y, width, destination.size.y), Rect2(source.position, Vector2(width / scale_factor, source.size.y)))
		x += width

func _draw() -> void:
	if texture == null: return
	_frame(Rect2(0, 0, size.x, area.position.y))
	_header()
	_frame(Rect2(0, area.position.y, area.position.x, area.size.y))
	_frame(Rect2(area.end.x, area.position.y, size.x - area.end.x, area.size.y))
	_band(Rect2(0, area.end.y, size.x, size.y - area.end.y), Rect2(0, 370, 1983, 304))
	Frame.paint(self, relief, Rect2(Vector2.ZERO, size), 6.0 * ui_scale)
