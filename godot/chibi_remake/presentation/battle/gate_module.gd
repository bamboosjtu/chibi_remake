extends Node2D
## Recessed double gate through the curtain wall, on the original MED footing.
const Textures = preload("res://presentation/battle/runtime_textures.gd")
const MATERIALS := "res://art/full/buildings/gate-materials-v6.png"
const DRAW_WIDTH := 65.7488555908203
const DRAW_HEIGHT := 87.0
const SOURCE_WIDTH := 659.0
const SOURCE_HEIGHT := 872.0
const LEGACY_WIDTH := 268.0*DRAW_WIDTH/SOURCE_WIDTH
const WIDTH := LEGACY_WIDTH*1.30
const HEIGHT := 348.0*DRAW_HEIGHT/SOURCE_HEIGHT
const FOOT_DEPTH := 10.0
const PASSAGE_HEIGHT := 47.0
const PIER_WIDTH := 7.0
const WALL_DEPTH := 34.0
const LINTEL := 4.0
static var material_texture: Texture2D
var panel: Polygon2D
var aperture := PackedVector2Array()
var recess: Node2D
var frame: Node2D
var foundation_drop := 0.0

static func slope(unit_id: int) -> float:
	return 0.5 if unit_id == 16 else -0.5

static func base_origin(unit_id: int) -> Vector2:
	var p := Vector2(22.1255722045898+246.0*DRAW_WIDTH/SOURCE_WIDTH,389.0*DRAW_HEIGHT/SOURCE_HEIGHT)
	return Vector2(88.0-p.x-LEGACY_WIDTH,p.y-LEGACY_WIDTH*absf(slope(unit_id))) if unit_id == 16 else p

static func origin(unit_id: int, foundation := 0.0) -> Vector2:
	var shift := (LEGACY_WIDTH-WIDTH)*0.5
	return base_origin(unit_id)+Vector2(shift,HEIGHT+FOOT_DEPTH+foundation-PASSAGE_HEIGHT+shift*slope(unit_id))

static func passage_height(_foundation: float) -> float:
	return PASSAGE_HEIGHT

static func depth_vector(unit_id: int) -> Vector2:
	return Vector2(WALL_DEPTH,-WALL_DEPTH*0.5) if unit_id == 16 else Vector2(-WALL_DEPTH,-WALL_DEPTH*0.5)

func _init(unit_id: int, _old_texture: Texture2D, _tint: Material, foundation := 0.0) -> void:
	foundation_drop = foundation
	if material_texture == null:
		var image := Textures.load_texture(MATERIALS,ResourceLoader.CACHE_MODE_REUSE,"formal").get_image()
		image.generate_mipmaps()
		material_texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var p := origin(unit_id,foundation)
	var along := Vector2(1,slope(unit_id))
	var edge := along*WIDTH
	var down := Vector2(0,PASSAGE_HEIGHT)
	var depth := depth_vector(unit_id)
	aperture = PackedVector2Array([p,p+edge,p+edge+down,p+down])
	frame = Node2D.new()
	add_child(frame)
	# Rear coping rests on the existing walkway, with no second plinth.
	var crown := p-Vector2(0,LINTEL)
	var outer_left := crown-along*PIER_WIDTH
	var outer_right := crown+along*(WIDTH+PIER_WIDTH)
	# A small headstone only: the existing curtain-wall walkway is left visible.
	var head_depth := depth.normalized()*5
	_surface(frame,PackedVector2Array([outer_left,outer_right,outer_right+head_depth,outer_left+head_depth]),2,Color(0.88,0.88,0.89))
	var returns := Node2D.new()
	add_child(returns)
	_surface(returns,PackedVector2Array([p,p+depth,p+down+depth,p+down]),3,Color(0.62,0.62,0.64))
	_surface(returns,PackedVector2Array([p+edge,p+edge+depth,p+edge+down+depth,p+edge+down]),3,Color(0.76,0.76,0.78))
	_surface(returns,PackedVector2Array([p,p+edge,p+edge+depth,p+depth]),3,Color(0.42,0.42,0.44))
	recess = Node2D.new()
	add_child(recess)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([p+down,p+edge+down,p+edge+down+depth,p+down+depth])
	shadow.color = Color(0.08,0.06,0.09,0.20)
	recess.add_child(shadow)
	# Both leaves are set back into the wall; their bottom is on the road plane.
	var door_recess := depth*0.12
	panel = _surface(self,PackedVector2Array([p+door_recess,p+edge+door_recess,p+edge+down+door_recess,p+down+door_recess]),1,Color.WHITE)
	var door_material := ShaderMaterial.new()
	door_material.shader = preload("res://art/full/gate_wood.gdshader")
	panel.material = door_material
	var seam := Line2D.new()
	seam.points = PackedVector2Array([p+edge*0.5+door_recess,p+edge*0.5+down+door_recess])
	seam.width = 0.65
	seam.default_color = Color(0.10,0.025,0.08,0.9)
	seam.antialiased = true
	panel.add_child(seam)
	var front := Node2D.new()
	add_child(front)
	var bottom := PASSAGE_HEIGHT+LINTEL
	_masonry(front,outer_left,along*PIER_WIDTH,Vector2(0,bottom),Color(0.82,0.82,0.83))
	_masonry(front,crown+edge,along*PIER_WIDTH,Vector2(0,bottom),Color(0.82,0.82,0.83))
	_masonry(front,crown,edge,Vector2(0,LINTEL),Color(0.84,0.84,0.85))

	_surface(front,PackedVector2Array([outer_left-Vector2(0,1.5),outer_right-Vector2(0,1.5),outer_right+Vector2(0,1),outer_left+Vector2(0,1)]),2,Color(0.78,0.78,0.79))
	remove_child(frame); add_child(frame)
	update_open(false)

func _masonry(parent: Node, p: Vector2, across: Vector2, down: Vector2, color: Color) -> void:
	var rows := maxi(1,ceili(down.length()/27.0))
	for row in range(rows):
		var a := float(row)/rows
		var b := float(row+1)/rows
		var face := _surface(parent,PackedVector2Array([p+down*a,p+across+down*a,p+across+down*b,p+down*b]),0,color)
		var half := material_texture.get_size()*0.5
		var width := minf(half.x-4,across.length()*19)
		var height := minf(half.y-4,down.length()/rows*19)
		face.uv = PackedVector2Array([Vector2(2,2),Vector2(width,2),Vector2(width,height),Vector2(2,height)])

func _surface(parent: Node, points: PackedVector2Array, tile: int, color: Color) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = points
	face.texture = material_texture
	face.color = color
	var half := material_texture.get_size()*0.5
	var start := Vector2(tile%2,floori(tile/2.0))*half+Vector2(3,3)
	var end := start+half-Vector2(6,6)
	face.uv = PackedVector2Array([start,Vector2(end.x,start.y),end,Vector2(start.x,end.y)])
	if tile == 3:
		var clipped := Geometry2D.intersect_polygons(points,aperture)
		face.visible = not clipped.is_empty()
		if not clipped.is_empty():
			face.polygon = clipped[0]
			var mapped := PackedVector2Array()
			var across := points[1]-points[0]
			var down := points[3]-points[0]
			var basis := Transform2D(across,down,points[0]).affine_inverse()
			for point in face.polygon:
				var f: Vector2 = basis*point
				mapped.append(start+f*(end-start))
			face.uv = mapped
	parent.add_child(face)
	return face

func update_open(opened: bool) -> void:
	panel.visible = not opened
	recess.visible = opened
