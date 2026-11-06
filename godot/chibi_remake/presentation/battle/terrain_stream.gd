extends Node2D
const Textures = preload("res://presentation/battle/runtime_textures.gd")
var host: Node2D
var chunks: Array = []
var active := {}
var loaded_bytes := 0
var budget := 402653184
const RESIDENT_FRACTION := 0.94 # Leave space for transient uploads and cache turnover.

func resident_limit() -> int:
	return int(budget * RESIDENT_FRACTION)

var last_rect := Rect2()
var event_patch: Sprite2D
var patch := {}
var gate_material: ShaderMaterial
var gate_patches: Array[Sprite2D] = []
var _wanted := {}
var _queued: Array = []
var _pending := {}
var _used := {}

## The worker owns only CPU image data; scene nodes and GPU uploads stay on main.
class DecodeJob extends RefCounted:
	var path: String
	var decoded: Image
	var error := OK
	func _init(source: String) -> void:path=source
	func decode() -> void:
		decoded=Image.new()
		var bytes:=FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():error=ERR_FILE_CANT_READ;return
		error=decoded.load_jpg_from_buffer(bytes) if path.ends_with(".bin") or path.ends_with(".jpg") else decoded.load_png_from_buffer(bytes)
func _init(h: Node2D, map_id: String) -> void:
	host = h
	var patches := FileAccess.open("res://art/full/terrain_events/manifest.json", FileAccess.READ)
	if patches != null:
		patch = JSON.parse_string(patches.get_as_text()).get(map_id, {})
	z_index = -100
	gate_material = ShaderMaterial.new()
	gate_material.shader = preload("res://art/full/gate_apertures.gdshader")
	_add_gate_patches(map_id)
	_setup_gate_apertures.call_deferred(map_id)
	var f := FileAccess.open("res://art/full/terrain_chunks/%s/manifest.json" % map_id, FileAccess.READ)
	if f != null:
		var data: Dictionary = JSON.parse_string(f.get_as_text())
		chunks = data.chunks
		budget = int(data.budgetBytes)

func _add_gate_patches(map_id: String) -> void:
	var file := FileAccess.open("res://art/full/gate_terrain/manifest.json",FileAccess.READ)
	if file == null: return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	for entry in data.maps.get(map_id,[]):
		# Road stays in the ground plane below the original opaque terrain.
		# Only the actual gate aperture reveals it; there is no raised sill.
		var road := Sprite2D.new()
		road.texture = Textures.load_texture(entry.roadTexture,ResourceLoader.CACHE_MODE_REUSE,"formal")
		road.centered = false
		road.position = Vector2(entry.position[0],entry.position[1])
		road.scale = Vector2.ONE/float(entry.scale)
		road.z_index = -1
		add_child(road)
		var sprite := Sprite2D.new()
		sprite.texture = Textures.load_texture(entry.texture,ResourceLoader.CACHE_MODE_REUSE,"formal")
		sprite.centered = false
		sprite.position = Vector2(entry.position[0],entry.position[1])
		sprite.scale = Vector2.ONE/float(entry.scale)
		sprite.z_index = 1
		sprite.material = gate_material
		add_child(sprite)
		sprite.set_meta("cell",Vector2i(int(entry.cell[0]),int(entry.cell[1])))
		gate_patches.append(sprite)

func _setup_gate_apertures(map_id: String) -> void:
	# A queued setup may run after a campaign switch removed this scene.
	if not is_inside_tree() or not is_instance_valid(host) or not host.is_inside_tree(): return
	var apertures := PackedVector4Array()
	var slopes := PackedFloat32Array()
	for u in host.units:
		if int(u.unit) not in [16,17]: continue
		var id := int(u.unit)
		var module = preload("res://presentation/battle/gate_module.gd")
		var offset: Vector2 = host.remaster_art.gate_wall_offset(map_id,Vector2i(int(u.A),int(u.B)))
		var foundation: float = host.remaster_art.gate_foundation_drop(map_id,Vector2i(int(u.A),int(u.B)))
		var p := Vector2(float(u.ax)-44,float(u.ay)-88)+module.origin(id,foundation)+offset
		apertures.append(Vector4(p.x,p.y,module.WIDTH,module.passage_height(foundation)))
		slopes.append(module.slope(id))
		for patch_sprite in gate_patches:
			if patch_sprite.get_meta("cell")==Vector2i(int(u.A),int(u.B)):
				preload("res://presentation/battle/gate_occlusion.gd").install(self,patch_sprite,p,module.slope(id),module.PASSAGE_HEIGHT,module.depth_vector(id).y-module.LINTEL,gate_material)

	gate_material.set_shader_parameter("gate_count",mini(apertures.size(),32))
	apertures.resize(32); slopes.resize(32)
	gate_material.set_shader_parameter("gates",apertures)
	gate_material.set_shader_parameter("slopes",slopes)

func _process(_delta: float) -> void:
	_finish_requests(false)
	if event_patch != null:
		for key in patch.get("keys", []):
			if not host.terrain_changes.has(key):
				event_patch.free()
				event_patch = null
				break
	if event_patch == null and not patch.is_empty():
		var changed := true
		for key in patch["keys"]:
			changed = changed and host.terrain_changes.has(key)
		if changed:
			event_patch = Sprite2D.new()
			event_patch.texture = Textures.load_texture(patch.texture)
			event_patch.centered = false
			event_patch.position = Vector2(patch.position[0], patch.position[1])
			event_patch.scale = Vector2.ONE / float(patch.scale)
			event_patch.z_index = 1
			add_child(event_patch)
	if host.cam == null:
		return
	var size: Vector2 = get_viewport_rect().size / host.cam.zoom
	var visible_rect := Rect2(host.cam.position - size * 0.5, size).grow(256)
	if visible_rect != last_rect:
		last_rect = visible_rect
		update_visible(visible_rect,false)
	_start_requests()

## Blocking is reserved for explicit inspection/tests. Runtime requests decode
## ahead of the camera and submit at most one completed texture per display frame.
func update_visible(rect: Rect2, blocking := true) -> void:
	var visible := []
	for i in range(chunks.size()):
		var r: Array = chunks[i].rect
		if rect.intersects(Rect2(r[0], r[1], r[2], r[3])):
			visible.append(i)
	var lod := 4
	while lod > 1 and estimate(visible, lod) > resident_limit():
		lod /= 2
	var wanted := {}
	for i in visible:
		wanted["%d/%d" % [i, lod]] = i
	_wanted=wanted
	_queued.clear()
	if blocking:_finish_requests(true)
	# Cache nearby offscreen chunks until their memory is needed again.
	for key in active:
		active[key].visible=wanted.has(key)
		if wanted.has(key):_used[key]=Engine.get_process_frames()
	for key in wanted:
		if active.has(key):
			continue
		if blocking:
			var job:=DecodeJob.new(str(chunks[wanted[key]].lods[str(lod)].texture))
			job.decode();_install_chunk(key,job)
		elif not _pending.has(key):_queued.append(key)
	if not blocking:_start_requests()
	assert(loaded_bytes <= budget)

func _start_requests() -> void:
	while _pending.size()<2 and not _queued.is_empty():
		var key: String=_queued.pop_front()
		if active.has(key) or _pending.has(key) or not _wanted.has(key):continue
		var lod:=str(key).get_slice("/",1)
		var entry: Dictionary=chunks[_wanted[key]].lods[lod]
		var job:=DecodeJob.new(str(entry.texture))
		var task:=WorkerThreadPool.add_task(job.decode,false,"Terrain "+key)
		_pending[key]={"task":task,"job":job}

func _finish_requests(blocking: bool) -> void:
	for key in _pending.keys():
		var request: Dictionary=_pending[key]
		if not blocking and not WorkerThreadPool.is_task_completed(int(request.task)):continue
		WorkerThreadPool.wait_for_task_completion(int(request.task))
		_pending.erase(key)
		if _wanted.has(key) and not active.has(key):_install_chunk(key,request.job)
		if not blocking:break

func _install_chunk(key: String, job: DecodeJob) -> void:
	if job.error!=OK:push_error("Invalid terrain chunk: "+job.path);return
	var entry: Dictionary=chunks[_wanted[key]]
	var lod:=int(key.get_slice("/",1))
	var weight:=int(entry.lods[str(lod)].bytes)
	while loaded_bytes+weight>resident_limit():
		var candidates: Array=active.keys().filter(func(k):return not _wanted.has(k))
		if candidates.is_empty():push_error("Terrain budget exceeded");return
		candidates.sort_custom(func(a,b):return int(_used.get(a,0))<int(_used.get(b,0)))
		_evict(str(candidates[0]))
	var sprite:=Sprite2D.new();sprite.material=gate_material
	sprite.texture=ImageTexture.create_from_image(job.decoded)
	sprite.centered=false;sprite.position=Vector2(entry.rect[0],entry.rect[1])
	sprite.scale=Vector2.ONE/float(lod);sprite.set_meta("bytes",weight)
	add_child(sprite);active[key]=sprite;_used[key]=Engine.get_process_frames()
	loaded_bytes+=weight

func _evict(key: String) -> void:
	var sprite: Sprite2D=active[key]
	loaded_bytes-=int(sprite.get_meta("bytes"));sprite.texture=null;sprite.free()
	active.erase(key);_used.erase(key)

func _exit_tree() -> void:
	# Join outstanding CPU jobs before freeing their owner on a map change.
	for request in _pending.values():WorkerThreadPool.wait_for_task_completion(int(request.task))
	_pending.clear()

func estimate(visible: Array, lod: int) -> int:
	var result := 0
	for i in visible:
		result += int(chunks[i].lods[str(lod)].bytes)
	return result
