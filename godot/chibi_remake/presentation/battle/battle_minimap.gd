extends Control
## Terrain persists after exploration; only current vision reveals enemy markers.
const Metrics=preload("res://presentation/hud/hud_metrics.gd")
static var catalog: Dictionary = {}
var host: Node2D
var view: Node2D
var terrain: TextureRect
var overlay: Control
var fog_material: ShaderMaterial
var map_texture: ImageTexture
var world_rect:=Rect2()
var gpu_markers := DisplayServer.get_name()!="headless" and "--cpu-minimap" not in OS.get_cmdline_user_args()
var marker_mesh: MultiMeshInstance2D
var camera_overlay: Control
var marker_capacity := 0
var marker_data := PackedFloat32Array()
var terrain_error := ""

func _init(h: Node2D,v: Node2D) -> void:
	host=h;view=v;mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var image := _terrain_image()
	map_texture=ImageTexture.create_from_image(image)
	terrain=TextureRect.new();terrain.texture=map_texture
	terrain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D fog_mask : filter_nearest;
uniform vec2 fog_uv_scale = vec2(1.0);
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float darkness = texture(fog_mask, UV * fog_uv_scale).a;
    COLOR = vec4(base.rgb * (1.0 - darkness), 1.0);
}"""
	fog_material=ShaderMaterial.new();fog_material.shader=shader
	terrain.material=fog_material;add_child(terrain)
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay);add_child(overlay)
	marker_mesh=MultiMeshInstance2D.new()
	var mesh:=QuadMesh.new();mesh.size=Vector2.ONE
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_colors=true;instances.mesh=mesh
	marker_mesh.multimesh=instances;overlay.add_child(marker_mesh)
	camera_overlay=Control.new();camera_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camera_overlay.draw.connect(_draw_camera);overlay.add_child(camera_overlay)

func _terrain_image() -> Image:
	if catalog.is_empty():
		var file := FileAccess.open("res://data/db/minimap_terrain.json",FileAccess.READ)
		if file == null: return _missing_terrain("缺少地形缩略图目录")
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary or not parser.data.get("maps") is Dictionary:
			return _missing_terrain("地形缩略图目录损坏")
		catalog=parser.data.maps
	var entry = catalog.get(str(host.map_id))
	if not entry is Dictionary or not entry.get("png") is String:
		return _missing_terrain("缺少当前关卡的地形缩略图")
	var bytes := Marshalls.base64_to_raw(entry.png)
	if bytes.size() <= 8 or bytes.slice(0,8) != PackedByteArray([137,80,78,71,13,10,26,10]):
		return _missing_terrain("地形缩略图不是有效 PNG")
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return _missing_terrain("地形缩略图解码失败")
	return image

func _missing_terrain(reason: String) -> Image:
	terrain_error=reason+"："+str(host.map_id)
	push_error(terrain_error)
	tooltip_text="地形缩略图不可用；单位标记和镜头导航仍可使用。"
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.12,0.11,0.09))
	return image

func _draw() -> void:
	if terrain==null:return
	var world_size:=Vector2(float(host.map_data.terrainW),float(host.map_data.terrainH))
	var k:=minf(size.x/world_size.x,size.y/world_size.y)
	world_rect=Rect2((size-world_size*k)*0.5,world_size*k)
	terrain.position=world_rect.position;terrain.size=world_rect.size
	overlay.size=size
	if view.fog_sprite!=null and view.fog_sprite.texture!=null:
		fog_material.set_shader_parameter("fog_mask",view.fog_sprite.texture)
		fog_material.set_shader_parameter("fog_uv_scale",world_size/(Vector2(host.visibility.width,host.visibility.height)*host.visibility.CELL))
		terrain.show()
	else:terrain.hide()
	overlay.queue_redraw()

func _draw_overlay() -> void:
	if world_rect.size.x<=0:return
	var k:=world_rect.size.x/float(host.map_data.terrainW)
	var off:=world_rect.position
	# Resolve the guarded read model once for this synchronous draw, not per dot.
	var player:=int(host.player_owner)
	var vision=host.visibility
	var scale: float=view.ui_scale
	var count:=0
	marker_mesh.visible=gpu_markers
	if gpu_markers:_reserve_markers(host.units.size())
	overlay.draw_rect(world_rect,Color(0.45,0.4,0.3),false,1.0)
	for unit: Dictionary in host.units:
		if not bool(unit.alive) or float(unit.die_t)>=0:continue
		if bool(unit.get("attached",false)) or int(unit.get("site_inside_uid",-1))>=0:continue
		var owner:=int(unit.owner)
		if owner!=player and not vision.is_visible(Vector2(unit.ax,unit.ay)):continue
		var color:=Color(0.55,0.55,0.55)
		if owner==player:color=Color(0.3,1.0,0.35)
		elif owner!=0:color=Color(1.0,0.3,0.25)
		var point:=off+Vector2(float(unit.ax),float(unit.ay))*k
		var d:float=(4.0 if bool(unit.is_building) else 2.5)*scale
		if gpu_markers:
			# One transform/color buffer upload; no GPU result is read by simulation.
			var index:=count*12
			marker_data[index]=d;marker_data[index+3]=point.x
			marker_data[index+5]=d;marker_data[index+7]=point.y
			marker_data[index+8]=color.r;marker_data[index+9]=color.g;marker_data[index+10]=color.b;marker_data[index+11]=color.a
			count+=1
		else:overlay.draw_rect(Rect2(point-Vector2.ONE*d*0.5,Vector2.ONE*d),color,true)
	if gpu_markers:
		marker_mesh.multimesh.buffer=marker_data
		marker_mesh.multimesh.visible_instance_count=count
	camera_overlay.queue_redraw()

func _reserve_markers(count: int) -> void:
	if count<=marker_capacity:return
	marker_capacity=maxi(64,marker_capacity)
	while marker_capacity<count:marker_capacity*=2
	marker_mesh.multimesh.instance_count=marker_capacity
	marker_data.resize(marker_capacity*12);marker_data.fill(0)

func _draw_camera() -> void:
	if world_rect.size.x<=0:return
	var k:=world_rect.size.x/float(host.map_data.terrainW)
	var off:=world_rect.position
	if view.cam!=null:
		var rect:Rect2=Metrics.visible_world_rect(view.cam.position,view.battle_rect(),get_viewport_rect().size,view.cam.zoom)
		camera_overlay.draw_rect(Rect2(off+rect.position*k,rect.size*k),Color(1,1,1,0.85),false,1.0)
