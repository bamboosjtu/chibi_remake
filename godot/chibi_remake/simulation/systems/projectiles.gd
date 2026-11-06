extends RefCounted
## 可存档的弹体模型；绘制频率、相机和贴图不参与命中结算。
const LIMIT := 100
const SPEED := {"arrow":16.0,"stone":8.0,"ambush":16.0}
const Access = preload("res://simulation/ports/projectiles_access.gd")
var host: Access
var active: Array = []

func _init(battle: Object) -> void: host = battle.simulation_access("projectiles") if battle.has_method("simulation_access") else battle

func launch(attacker: Dictionary, target: Dictionary, kind: String) -> bool:
	if active.size() >= LIMIT or not SPEED.has(kind): return false
	var cell: Vector2i = host._cell_of_px(target.ax,target.ay)
	active.append({"kind":kind,"sourceUid":int(attacker.uid),"targetUid":int(target.uid),
		"owner":int(attacker.owner),"x":float(attacker.ax),"y":float(attacker.ay),
		"tx":float(target.ax),"ty":float(target.ay),"travel":0.0,
		"a":cell.x,"b":cell.y,"damage":int(host._damage(attacker,target)),
		"attackCents":roundi(host.CombatRules.attack(attacker,true)*100.0)})
	return true

static func distance(effect: Dictionary) -> float:
	return Vector2(effect.tx-effect.x,effect.ty-effect.y).length()

static func position_of(effect: Dictionary) -> Vector2:
	var origin := Vector2(effect.x,effect.y)
	var offset := Vector2(effect.tx-effect.x,effect.ty-effect.y)
	return origin+offset*minf(1.0,float(effect.travel)/maxf(0.0001,offset.length()))

func step() -> void:
	var survivors: Array=[]
	for effect in active:
		effect.travel = minf(distance(effect),float(effect.travel)+float(SPEED[effect.kind]))
		if float(effect.travel) < distance(effect): survivors.append(effect)
		else: host._projectile_arrived(effect)
	active=survivors

func snapshot() -> Array: return active.duplicate(true)

func valid_snapshot(value: Variant) -> bool:
	if not value is Array or value.size()>LIMIT: return false
	for effect in value:
		if not effect is Dictionary or not SPEED.has(effect.get("kind","")): return false
		for key in ["sourceUid","targetUid","owner","a","b","damage","attackCents"]:
			var number=effect.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or float(number)<0 or float(number)>2147483647: return false
		if int(effect.owner)<1 or int(effect.damage)<1: return false
		for key in ["x","y","tx","ty","travel"]:
			var number=effect.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)<0: return false
		if float(effect.x)>float(host.map_data.terrainW) or float(effect.tx)>float(host.map_data.terrainW) or float(effect.y)>float(host.map_data.terrainH) or float(effect.ty)>float(host.map_data.terrainH): return false
		if float(effect.travel)>distance(effect): return false
		if int(effect.a)>=int(host.map_data.rows) or int(effect.b)>=int(host.map_data.cols): return false
	return true

func restore(value: Array) -> void: active=value.duplicate(true)
