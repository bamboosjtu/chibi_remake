extends Node2D
## OTHER#7 与采集目标共用 MED 格位；独立于地形烘焙和高清分块。
var host: Node2D
var texture: Texture2D
var frames: Array = []
var active := {}
var signature: Array = []
var projection: Array = []
var projection_builds := 0

func _init(h: Node2D) -> void:
	host = h
	texture = host.remaster_art.runtime_texture("resource-decor")
	frames = host.remaster_art.runtime_info("resource-decor").get("frames", [])

func _process(_delta: float) -> void:
	if host.cam == null or texture == null:
		return
	var size: Vector2 = get_viewport_rect().size / host.cam.zoom
	var rect := Rect2(host.cam.position - size * 0.5, size).grow(80)
	update_visible(rect)

func update_visible(rect: Rect2) -> void:
	var key: Array = host.resource_layer_key(rect)
	if key == signature: return
	signature = key
	projection = host.resource_layer_projection(rect) if not key.is_empty() else []
	projection_builds += 1
	var wanted := {}
	for descriptor in projection: wanted[int(descriptor.index)] = true
	for i in active.keys():
		if not wanted.has(i):
			active[i].free()
			active.erase(i)
	for descriptor in projection:
		var i := int(descriptor.index)
		var phase := int(descriptor.phase)
		var mapping: Dictionary = frames[phase] if phase >= 0 and phase < frames.size() else {}
		if active.has(i):
			if int(active[i].get_meta("phase", -1)) != phase or bool(mapping.get("skip",false)):
				active[i].free(); active.erase(i)
		if bool(mapping.get("skip", false)): continue
		if not active.has(i):
			active[i] = _create_sprite(phase,mapping)
		var sprite: Sprite2D = active[i]
		# Reused index/phase can describe another position after a world or geometry change.
		var anchor: Vector2 = descriptor.anchor
		var offset := Vector2.ZERO
		if not mapping.is_empty():
			var draw: Array = mapping.draw
			offset=Vector2(draw[0],draw[1])
		sprite.position = anchor-Vector2(22,60)+offset
		sprite.z_index = clampi(int(anchor.y),0,4096)

func _create_sprite(phase: int, mapping: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.set_meta("phase",phase)
	sprite.texture=texture
	sprite.centered=false
	sprite.region_enabled=true
	if not mapping.is_empty():
		var region: Array = mapping.region
		var draw: Array = mapping.draw
		sprite.region_rect=Rect2(region[0],region[1],region[2],region[3])
		sprite.scale=Vector2(float(draw[2])/float(region[2]),float(draw[3])/float(region[3]))
	else:
		sprite.region_rect=Rect2(0,phase*60,44,60)
	add_child(sprite)
	return sprite
