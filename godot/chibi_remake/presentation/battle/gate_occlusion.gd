extends RefCounted
## Reuse the baked wall pixels at their own depth. Ground outside the wall slab
## stays in the terrain plane; the same aperture shader leaves the passage open.
static func install(parent:Node2D,patch:Sprite2D,opening:Vector2,slope:float,height:float,rear:float,material:ShaderMaterial) -> void:
	var scale:float=patch.scale.x
	var width:float=patch.texture.get_width()*scale
	for x in range(0,ceili(width),2):
		var left:float=patch.position.x+x
		var right:float=minf(left+2.0,patch.position.x+width)
		var y0:float=opening.y+(left-opening.x)*slope
		var y1:float=opening.y+(right-opening.x)*slope
		var points:=PackedVector2Array([Vector2(left,y0+rear),Vector2(right,y1+rear),Vector2(right,y1+height),Vector2(left,y0+height)])
		var face:=Polygon2D.new();face.name="GateWallDepth"
		face.set_meta("gate_occluder",true)
		face.texture=patch.texture;face.material=material;face.polygon=points
		var uv:=PackedVector2Array()
		for point in points:uv.append((point-patch.position)/scale)
		face.uv=uv;face.z_as_relative=false
		face.z_index=clampi(roundi((y0+y1)*0.5+height),-4096,4094)
		parent.add_child(face)
