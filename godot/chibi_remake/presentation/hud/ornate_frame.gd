extends Control
## 固定宽度九切片：透明框心由真正的控件内容填充。
const Textures = preload("res://presentation/battle/runtime_textures.gd")
var texture: Texture2D
var edge := 8.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = Textures.load_texture("res://art/full/ui/hud-ornate-frame-v3.png")
	resized.connect(queue_redraw)

static func paint(node: CanvasItem, image: Texture2D, rect: Rect2, border: float) -> void:
	if image == null or rect.size.x <= 0 or rect.size.y <= 0: return
	var sz := image.get_size()
	var margin := sz * 0.13
	var bx := minf(border, rect.size.x / 2)
	var by := minf(border, rect.size.y / 2)
	var sx := [0.0, margin.x, sz.x - margin.x, sz.x]
	var sy := [0.0, margin.y, sz.y - margin.y, sz.y]
	var dx := [rect.position.x, rect.position.x + bx, rect.end.x - bx, rect.end.x]
	var dy := [rect.position.y, rect.position.y + by, rect.end.y - by, rect.end.y]
	for y in range(3):
		for x in range(3):
			if x == 1 and y == 1: continue
			node.draw_texture_rect_region(image, Rect2(dx[x], dy[y], dx[x+1]-dx[x], dy[y+1]-dy[y]), Rect2(sx[x], sy[y], sx[x+1]-sx[x], sy[y+1]-sy[y]))

func _draw() -> void:
	paint(self, texture, Rect2(Vector2.ZERO, size), edge)
