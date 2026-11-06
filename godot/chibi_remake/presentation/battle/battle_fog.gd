extends Sprite2D
## 遮罩只消费模拟层探索数据；HUD 不受遮罩影响。
var _read_visibility: Callable
var _state: RefCounted
var visibility: RefCounted:
	get: return _read_visibility.call()
var _revision := -1
func _init(read_visibility: Callable) -> void:
	_read_visibility = read_visibility
	centered = false
	scale = Vector2(22, 11)
	z_index = 4095
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	var state := visibility
	if not is_same(state, _state):
		_state = state
		_revision = -1
		texture = null
	if state.revision == _revision: return
	_revision = state.revision
	var pixels := PackedByteArray()
	pixels.resize(state.width * state.height * 4)
	for i in range(state.current.size()):
		pixels[i * 4 + 3] = 0 if state.current[i] else (165 if state.explored[i] else 255)
	var mask := Image.create_from_data(state.width, state.height, false, Image.FORMAT_RGBA8, pixels)
	if texture == null: texture = ImageTexture.create_from_image(mask)
	else: (texture as ImageTexture).update(mask)
