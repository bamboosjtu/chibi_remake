extends RefCounted
## 完整图集与武将头像。视觉采样区域独立于世界尺寸/实体状态。
const MANIFEST := "res://art/full/manifest.json"
const Textures = preload("res://presentation/battle/runtime_textures.gd")
const TEAM_SHADER = preload("res://art/full/team_color.gdshader")
const TEAM_COLORS := {0: Color("c54ea0"), 1: Color("18b9ee"), 2: Color("cf4231"), 3: Color("38b4a7"), 4: Color("57ac55")}
var _data: Dictionary = {}
var _textures: Dictionary = {}
const TEXTURE_CACHE_BYTES := 268435456
var _texture_order: Array[String] = []
var _texture_weights := {}
var _cached_bytes := 0
var _neutral_mask: Texture2D
var _materials: Dictionary = {}
var _gate_terrain := {}
var _palette: Dictionary = {}
var _unit_layouts: Dictionary = {}
var _display_frames: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary and int(data.get("schemaVersion", 0)) == 1:
		_data = data
	var layouts := FileAccess.open("res://data/db/unit_display_layout.json", FileAccess.READ)
	if layouts != null:
		_unit_layouts = JSON.parse_string(layouts.get_as_text()).get("units", {})

func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = Textures.load_texture(path, ResourceLoader.CACHE_MODE_REUSE, "formal")
		var loaded: Texture2D = _textures[path]
		var weight := loaded.get_width() * loaded.get_height() * 4 if loaded != null else 0
		_texture_weights[path] = weight
		_cached_bytes += weight
	_texture_order.erase(path)
	_texture_order.append(path)
	# 当前 Sprite 保持其页的引用；缓存只保留有限的最近使用页。
	while _cached_bytes > TEXTURE_CACHE_BYTES and _texture_order.size() > 1:
		var oldest: String = _texture_order.pop_front()
		_cached_bytes -= int(_texture_weights.get(oldest, 0))
		_texture_weights.erase(oldest)
		_textures.erase(oldest)
	return _textures[path]

func officer_texture(index: int) -> Texture2D:
	var entry: Dictionary = _data.get("officers", {}).get(str(index), {})
	return _texture(str(entry.get("texture", "")))

## 大型画面（标题、菜单、结局等）按稳定键取图，例如 background-bmp-054。
func background_texture(key: String) -> Texture2D:
	var entry: Dictionary = _data.get("backgrounds", {}).get(str(key), {})
	return _texture(str(entry.get("texture", "")))

func unit_icon(unit_id: int) -> Texture2D:
	var atlas: Dictionary = _data.get("atlases", {}).get(str(unit_id), {})
	var frames: Array = atlas.get("frames", [])
	if frames.is_empty(): return null
	var frame: Dictionary = frames[0]
	var texture := _texture(str(frame.get("texture", atlas.get("texture", ""))))
	if texture == null: return null
	var region: Array = frame.region
	var icon := AtlasTexture.new()
	icon.atlas = texture
	icon.region = Rect2(region[0], region[1], region[2], region[3])
	icon.filter_clip = true
	return icon

func runtime_info(key: String) -> Dictionary:
	return _data.get("runtimeAssets", {}).get(key, {})

func gate_wall_offset(map_id: String, cell: Vector2i) -> Vector2:
	var values: Array = _data.get("gateWallOffsets", {}).get(map_id, {}).get("%d/%d" % [cell.x, cell.y], [0,0])
	return Vector2(float(values[0]),float(values[1]))

func gate_foundation_drop(map_id: String, cell: Vector2i) -> float:
	if _gate_terrain.is_empty():
		var file := FileAccess.open("res://art/full/gate_terrain/manifest.json",FileAccess.READ)
		if file == null: return 0
		_gate_terrain = JSON.parse_string(file.get_as_text())
	for entry in _gate_terrain.get("maps",{}).get(map_id,[]):
		if int(entry.cell[0]) == cell.x and int(entry.cell[1]) == cell.y: return float(entry.get("foundationDrop",0))
	return 0

func runtime_texture(key: String) -> Texture2D:
	return _texture(str(runtime_info(key).get("texture", "")))

func terrain_info(map_id: String) -> Dictionary:
	var chunks := "res://art/full/terrain_chunks/%s/manifest.json" % map_id.to_lower()
	if FileAccess.file_exists(chunks):
		return {"streamingManifest": chunks}
	return {}

func _team_material(owner: int) -> ShaderMaterial:
	# 高清母版为青蓝阵营色；owner 是显示色槽，不能把 army 2 固定为母版色。
	var key := str(owner)
	if not _materials.has(key):
		if _palette.is_empty():
			var file := FileAccess.open("res://art/full/team_palette.json", FileAccess.READ)
			if file != null:
				var parsed = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary:
					_palette = parsed
		var material := ShaderMaterial.new()
		material.shader = TEAM_SHADER
		# 高清图按实际青蓝布料换色，不再上传不匹配的旧整张像素遮罩。
		if _neutral_mask == null:
			var neutral := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			neutral.fill(Color.WHITE)
			_neutral_mask = ImageTexture.create_from_image(neutral)
		material.set_shader_parameter("team_mask", _neutral_mask)
		material.set_shader_parameter("use_redrawn_blue", true)
		material.set_shader_parameter("team_color", TEAM_COLORS.get(owner, TEAM_COLORS[2]))
		if _palette.has("owners"):
			var ramp: Dictionary = _palette.owners.get(str(owner), _palette.owners["2"])
			var gradient := Gradient.new()
			var offsets := PackedFloat32Array([0.0])
			var colors := PackedColorArray([Color.BLACK])
			for i in range(10):
				var rgb: Array = ramp.colors[i]
				offsets.append(float(_palette.sourceLuma[i]))
				colors.append(Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0))
			var last: Array = ramp.colors[10]
			offsets.append(1.0)
			colors.append(Color(float(last[0]) / 255.0, float(last[1]) / 255.0, float(last[2]) / 255.0))
			gradient.offsets = offsets
			gradient.colors = colors
			var texture := GradientTexture1D.new()
			texture.gradient = gradient
			texture.width = 256
			material.set_shader_parameter("team_ramp", texture)
			material.set_shader_parameter("use_source_palette", true)
		_materials[key] = material
	return _materials[key]

func create_skin(parent: Sprite2D, unit_id: int, owner: int, frame_size: Vector2i) -> Sprite2D:
	var entry: Dictionary = _data.get("atlases", {}).get(str(unit_id), {})
	if entry.is_empty():
		return null
	var texture := _texture(str(entry.get("texture", "")))
	if texture == null:
		return null
	var skin := Sprite2D.new()
	skin.name = "FullRemasterSkin"
	skin.texture = texture
	skin.centered = false
	skin.region_enabled = true
	if bool(entry.get("teamTintable", true)):
		skin.material = _team_material(owner)
	skin.set_meta("owner", owner)
	skin.set_meta("team_tintable", bool(entry.get("teamTintable", false)))
	var frames: Array = entry.get("frames", [])
	if _display_frames.has(unit_id):
		frames = _display_frames[unit_id]
	elif _unit_layouts.has(str(unit_id)):
		frames = frames.duplicate(true)
		for key in _unit_layouts[str(unit_id)]:
			var index := int(key)
			if index < frames.size(): frames[index].merge(_unit_layouts[str(unit_id)][key], true)
		_display_frames[unit_id] = frames
	skin.set_meta("full_frames", frames)
	skin.set_meta("parent_scale", Vector2(float(frame_size.x) / float(entry.worldWidth), float(frame_size.y) / float(entry.worldHeight)))
	parent.add_child(skin)
	update_frame(skin, 0)
	return skin

func update_frame(skin: Sprite2D, frame: int) -> bool:
	if not skin.has_meta("full_frames"):
		return false
	var frames: Array = skin.get_meta("full_frames")
	if frame < 0 or frame >= frames.size():
		skin.visible = false
		return true
	var entry: Dictionary = frames[frame]
	if bool(entry.get("original", false)):
		skin.visible = false
		return false
	skin.visible = not bool(entry.get("skip", false))
	if not skin.visible:
		return true
	var region: Array = entry.region
	var draw: Array = entry.draw
	if entry.has("texture"):
		var texture := _texture(str(entry.texture))
		if texture == null:
			skin.visible = false
			return true
		skin.texture = texture
	if bool(skin.get_meta("team_tintable", false)):
		skin.material = _team_material(int(skin.get_meta("owner", 2)))
	var k: Vector2 = skin.get_meta("parent_scale")
	skin.region_rect = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	skin.position = (Vector2(float(draw[0]), float(draw[1])) + skin.get_meta("wall_offset", Vector2.ZERO)) * k
	skin.scale = Vector2(float(draw[2]) / float(region[2]), float(draw[3]) / float(region[3])) * k
	return true
