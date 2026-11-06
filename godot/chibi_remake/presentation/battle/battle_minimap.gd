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

func _init(h: Node2D,v: Node2D) -> void:
	host=h;view=v;mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if catalog.is_empty():
		var file:=FileAccess.open("res://data/db/minimap_terrain.json",FileAccess.READ)
		assert(file!=null,"Missing minimap terrain catalog")
		catalog=JSON.parse_string(file.get_as_text()).maps
	var entry: Dictionary=catalog.get(str(host.map_id),{})
	assert(not entry.is_empty(),"Missing map thumbnail: "+str(host.map_id))
	var image:=Image.new()
	# Decode outside assert: release templates strip assertions and their operands.
	var error := image.load_png_from_buffer(Marshalls.base64_to_raw(str(entry.png)))
	if error != OK:
		push_error("Cannot decode minimap terrain for " + str(host.map_id))
		return
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
	overlay.draw_rect(world_rect,Color(0.45,0.4,0.3),false,1.0)
	for unit in host.units:
		if not bool(unit.alive) or float(unit.die_t)>=0:continue
		if bool(unit.get("attached",false)) or int(unit.get("site_inside_uid",-1))>=0:continue
		var owner:=int(unit.owner)
		if owner!=int(host.player_owner) and not host.visibility.is_visible(Vector2(unit.ax,unit.ay)):continue
		var color:=Color(0.55,0.55,0.55)
		if owner==int(host.player_owner):color=Color(0.3,1.0,0.35)
		elif owner!=0:color=Color(1.0,0.3,0.25)
		var point:=off+Vector2(float(unit.ax),float(unit.ay))*k
		var d:float=(4.0 if bool(unit.is_building) else 2.5)*view.ui_scale
		overlay.draw_rect(Rect2(point-Vector2.ONE*d*0.5,Vector2.ONE*d),color,true)
	if view.cam!=null:
		var rect:Rect2=Metrics.visible_world_rect(view.cam.position,view.battle_rect(),get_viewport_rect().size,view.cam.zoom)
		overlay.draw_rect(Rect2(off+rect.position*k,rect.size*k),Color(1,1,1,0.85),false,1.0)
