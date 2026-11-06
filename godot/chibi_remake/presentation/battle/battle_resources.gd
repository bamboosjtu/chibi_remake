extends Node2D
## OTHER#7 与采集目标共用 MED 格位；独立于地形烘焙和高清分块。
var host: Node2D
var texture: Texture2D
var frames: Array = []
var active := {}
var last_rect := Rect2()
var last_revision := -1
var entries: Array = []

func _init(h: Node2D) -> void:
	host = h
	entries = host.map_data.get("decor", [])
	texture = host.remaster_art.runtime_texture("resource-decor")
	frames = host.remaster_art.runtime_info("resource-decor").get("frames", [])

func _process(_delta: float) -> void:
	if host.cam == null or texture == null:
		return
	var size: Vector2 = get_viewport_rect().size / host.cam.zoom
	var rect := Rect2(host.cam.position - size * 0.5, size).grow(80)
	if rect == last_rect and last_revision == host.resource_revision:
		return
	last_rect = rect
	last_revision = host.resource_revision
	update_visible(rect)

func update_visible(rect: Rect2) -> void:
	var wanted := {}
	for i in range(entries.size()):
		var cell: Array = entries[i]
		var anchor: Vector2 = host.nav.anchor_of(int(cell[0]), int(cell[1]))
		if rect.intersects(Rect2(anchor - Vector2(22, 60), Vector2(44, 60))):
			wanted[i] = anchor
	for i in active.keys():
		if not wanted.has(i):
			active[i].free()
			active.erase(i)
	for i in wanted:
		var cell: Array = entries[i]
		var model: Dictionary = host.decor_cells.get("%d_%d" % [int(cell[0]), int(cell[1])], {})
		var phase := int(model.get("phase", cell[2]))
		if active.has(i):
			if int(active[i].get_meta("phase", -1)) == phase: continue
			active[i].free()
			active.erase(i)
		var mapping: Dictionary = frames[phase] if phase >= 0 and phase < frames.size() else {}
		if bool(mapping.get("skip", false)): continue
		var sprite := Sprite2D.new()
		sprite.set_meta("phase", phase)
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		if not mapping.is_empty():
			var region: Array = mapping.region
			var draw: Array = mapping.draw
			sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
			sprite.scale = Vector2(float(draw[2]) / float(region[2]), float(draw[3]) / float(region[3]))
			sprite.position = wanted[i] - Vector2(22, 60) + Vector2(draw[0], draw[1])
		else:
			sprite.region_rect = Rect2(0, phase * 60, 44, 60)
			sprite.position = wanted[i] - Vector2(22, 60)
		sprite.z_index = clampi(int(wanted[i].y), 0, 4096)
		add_child(sprite)
		active[i] = sprite
