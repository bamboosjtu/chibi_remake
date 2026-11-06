extends Node2D
## 世界空间矢量箭杆、箭头和投石；随镜头缩放保持清晰，不影响模型结算。
var host: Node2D
var impacts: Array=[]

func _init(battle: Node2D) -> void:
	host=battle;z_index=4095

func impact(point: Vector2) -> void:
	impacts.append({"point":point,"life":0.0})

func _process(delta: float) -> void:
	for effect in impacts: effect.life+=delta
	impacts=impacts.filter(func(effect):return effect.life<0.22)
	queue_redraw()

func _draw() -> void:
	for effect in host.projectiles.active:
		var point: Vector2=host.projectiles.position_of(effect)
		if not host.visibility.is_visible(point): continue
		var direction:=Vector2(effect.tx-effect.x,effect.ty-effect.y).normalized()
		if direction==Vector2.ZERO:direction=Vector2.RIGHT
		if effect.kind in ["arrow","ambush"]:
			point-=Vector2(0,12)
			var tail:=point-direction*15
			var side:=direction.orthogonal()
			draw_line(tail+Vector2(0,1),point+Vector2(0,1),Color(0.08,0.05,0.02,0.7),3,true)
			draw_line(tail,point-direction*3,Color(0.72,0.48,0.22),1.4,true)
			draw_colored_polygon(PackedVector2Array([point+direction*3,point-direction*3+side*2,point-direction*3-side*2]),Color(0.84,0.82,0.66))
			draw_line(tail,tail+direction*4+side*2,Color(0.68,0.24,0.17),1.2,true)
			draw_line(tail,tail+direction*4-side*2,Color(0.68,0.24,0.17),1.2,true)
		else:
			var ratio: float=float(effect.travel)/maxf(1.0,host.projectiles.distance(effect))
			draw_circle(point,4,Color(0.04,0.03,0.02,0.35),true,-1,true)
			point.y-=10+sin(ratio*PI)*28
			draw_colored_polygon(PackedVector2Array([point+Vector2(-4,-2),point+Vector2(-1,-5),point+Vector2(4,-3),point+Vector2(5,2),point+Vector2(0,5),point+Vector2(-5,2)]),Color(0.29,0.27,0.23))
			draw_colored_polygon(PackedVector2Array([point+Vector2(-4,-2),point+Vector2(-1,-5),point+Vector2(4,-3),point+Vector2(0,0)]),Color(0.65,0.61,0.51))
	for fire in host.fire_fields.active:
		var point:Vector2=host.nav.anchor_of(int(fire.a),int(fire.b))
		if not host.visibility.is_visible(point):continue
		var fade:float=minf(1.0,float(100-int(fire.age))/12.0)
		for i in range(3):
			var foot:Vector2=point+Vector2((i-1)*7,absf(i-1)*2)
			var sway:float=sin(float(fire.age)*0.7+i*2)*3
			var height:float=15+sin(float(fire.age)*0.8+i)*5
			draw_colored_polygon(PackedVector2Array([foot+Vector2(-5,0),foot+Vector2(-6,-7),foot+Vector2(sway,-height),foot+Vector2(6,-5),foot+Vector2(4,1)]),Color(1,0.25,0.02,0.85*fade))
			draw_colored_polygon(PackedVector2Array([foot+Vector2(-3,0),foot+Vector2(sway*0.5,-height*0.6),foot+Vector2(3,0)]),Color(1,0.85,0.18,fade))
	for effect in impacts:
		var point: Vector2=effect.point
		if not host.visibility.is_visible(point):continue
		var progress: float=effect.life/0.22
		draw_arc(point,3+progress*13,0,TAU,16,Color(0.83,0.65,0.36,1-progress),1.5,true)
