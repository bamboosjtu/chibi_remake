extends RefCounted
## 运行素材的统一入口：全部转交完整图集清单（art/full/manifest.json）。
## 旧的 art/remaster 兼容清单已移除，不再保留第二套素材来源。

const FullArt = preload("res://presentation/battle/full_art_catalog.gd")
var _full_art := FullArt.new()

func terrain_info(map_id: String) -> Dictionary:
	return _full_art.terrain_info(map_id)

func officer_texture(index: int) -> Texture2D:
	return _full_art.officer_texture(index)

func unit_icon(unit_id: int) -> Texture2D:
	return _full_art.unit_icon(unit_id)

func runtime_info(key: String) -> Dictionary:
	return _full_art.runtime_info(key)

func runtime_texture(key: String) -> Texture2D:
	return _full_art.runtime_texture(key)

func gate_wall_offset(map_id: String, cell: Vector2i) -> Vector2:
	return _full_art.gate_wall_offset(map_id, cell)

func gate_foundation_drop(map_id: String, cell: Vector2i) -> float:
	return _full_art.gate_foundation_drop(map_id,cell)

func create_unit_skin(parent: Sprite2D, unit_id: int, owner: int, frame_size: Vector2i) -> Sprite2D:
	var full_skin := _full_art.create_skin(parent, unit_id, owner, frame_size)
	if full_skin != null:
		return full_skin
	push_error("Missing HD unit atlas: %d" % unit_id)
	return null

func update_skin(skin: Sprite2D, frame: int, _is_building: bool, _death_time: float) -> bool:
	return _full_art.update_frame(skin, frame)

func menu_background() -> Texture2D:
	return _full_art.background_texture("background-bmp-054")
