extends Sprite2D
## 遮罩只消费模拟层探索数据；HUD 不受遮罩影响。
var _read_visibility: Callable
var _state: RefCounted
var visibility: RefCounted:
	get: return _read_visibility.call()
var _revision := -1
var _target: SubViewport
var _quad: ColorRect
var _current_texture: ImageTexture
var _explored_texture: ImageTexture
var upload_microseconds := 0

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
	var begin:=Time.get_ticks_usec()
	if DisplayServer.get_name()=="headless":
		_cpu_mask(state) # Assertion-enabled, non-rendering tests can still inspect alpha.
	else:
		_gpu_mask(state)
	upload_microseconds+=Time.get_ticks_usec()-begin

func _cpu_mask(state: RefCounted) -> void:
	var pixels := PackedByteArray()
	pixels.resize(state.width * state.height * 4)
	for i in range(state.current.size()):
		pixels[i * 4 + 3] = 0 if state.current[i] else (165 if state.explored[i] else 255)
	var mask := Image.create_from_data(state.width, state.height, false, Image.FORMAT_RGBA8, pixels)
	if texture == null: texture = ImageTexture.create_from_image(mask)
	else: (texture as ImageTexture).update(mask)

## Upload the simulation's two byte planes directly. A small render target keeps
## the public RGBA mask shared by the battlefield and minimap; no per-cell script
## conversion runs on a rendered frame. The 0/1 bytes are normalized by R8.
func _gpu_mask(state: RefCounted) -> void:
	var dimensions:=Vector2i(state.width,state.height)
	var current:=Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_R8,state.current)
	var explored:=Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_R8,state.explored)
	if _target==null:
		_target=SubViewport.new();_target.disable_3d=true;_target.transparent_bg=true
		_target.gui_disable_input=true;add_child(_target)
		_quad=ColorRect.new();_quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var shader:=Shader.new()
		shader.code="""shader_type canvas_item;
uniform sampler2D current_mask : filter_nearest;
uniform sampler2D explored_mask : filter_nearest;
void fragment() {
    float visible = step(0.5 / 255.0, texture(current_mask, UV).r);
    float known = step(0.5 / 255.0, texture(explored_mask, UV).r);
    COLOR = vec4(0.0, 0.0, 0.0, (1.0 - visible) * mix(1.0, 165.0 / 255.0, known));
}"""
		var mask_material:=ShaderMaterial.new();mask_material.shader=shader;_quad.material=mask_material
		_target.add_child(_quad)
	if _current_texture==null or _target.size!=dimensions:
		_target.size=dimensions;_quad.size=Vector2(dimensions)
		_current_texture=ImageTexture.create_from_image(current);_explored_texture=ImageTexture.create_from_image(explored)
		(_quad.material as ShaderMaterial).set_shader_parameter("current_mask",_current_texture)
		(_quad.material as ShaderMaterial).set_shader_parameter("explored_mask",_explored_texture)
	else:
		_current_texture.update(current);_explored_texture.update(explored)
	texture=_target.get_texture()
	_target.render_target_update_mode=SubViewport.UPDATE_ONCE
