extends RefCounted
const ContextProjection = preload("res://app/read_models/context_projection.gd")
const ResourceProjection = preload("res://app/read_models/resource_projection.gd")
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
var _read_live: Callable
var _context_projection: ContextProjection
var _resource_projection: ResourceProjection

func _init(read_live: Callable, context_projection: ContextProjection, resource_projection: ResourceProjection) -> void:
	_read_live = read_live
	_context_projection = context_projection
	_resource_projection = resource_projection


func map_caption() -> String:
	var data: Object = _read_live.call()
	return str(data.map_data.get("name","")) if data != null else ""

func gate_passage_width(cell: Vector2i, standard_width: float) -> float:
	var data: Object = _read_live.call()
	if data == null: return standard_width
	var passages: Dictionary = data.map_data.get("navigation", {}).get("gatePassages", {})
	return float(passages.get("%d/%d" % [cell.x, cell.y], {}).get("width", standard_width))

func visibility_view() -> Dictionary:
	var data: Object = _read_live.call()
	return _context_projection.visibility(data) if data != null else {}

func visibility_planes(key: Array) -> Dictionary:
	var data: Object = _read_live.call()
	return _context_projection.visibility_planes(data,key) if data != null else {}

func visibility_geometry() -> Vector2:
	var data: Object = _read_live.call()
	if data == null: return Vector2.ZERO
	return Vector2(data.visibility.width,data.visibility.height)*data.visibility.CELL

func point_visible(point: Vector2) -> bool:
	var data: Object = _read_live.call()
	return data.visibility.is_visible(point) if data != null else false

func terrain_has_changes(keys: Array) -> bool:
	var data: Object = _read_live.call()
	return keys.all(func(key): return data.terrain_changes.has(key)) if data != null else false

func camera_bounds() -> Vector2:
	var data: Object = _read_live.call()
	return Vector2(float(data.map_data.get("terrainW",0)), float(data.map_data.get("terrainH",0))) if data != null else Vector2.ZERO

func opening_camera_position() -> Vector2:
	var data: Object = _read_live.call()
	if data == null: return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	var count := 0
	for unit in data.units:
		if int(unit.owner) == int(data.player_owner) and not bool(unit.is_building) and bool(unit.alive):
			x += float(unit.ax); y += float(unit.ay); count += 1
	return Vector2(x/count,y/count) if count > 0 else camera_bounds() * 0.5

func camera_tile_geometry() -> Vector3:
	var data: Object = _read_live.call()
	return Vector3(float(data.tile_w),float(data.tile_hw),float(data.tile_hh)) if data != null else Vector3.ZERO

func construction_preview_key(point: Vector2) -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	if data.world.world_orders.cmd_pending_kind() != "build": return []
	var bid := int(data.cmd_pending_data.get("unit", -1))
	var meta: Dictionary = data.map_data.units.get(str(bid), {})
	var selected := []
	for unit in data.selected: selected.append(int(unit.uid))
	selected.make_read_only()
	# Values only. A replacement world can have identical ticks, UIDs and nav versions.
	var result := [data.world.get_instance_id(), data.nav.get_instance_id(), bid,
		data.nav.cell_of_px(point.x,point.y), data.sim_tick, data.nav.version, data.units.size(), selected,
		data.gold, data.wood, data.food, data.stone, data.game_end, data.player_owner, data.cheat_build_any,
		meta.get("w",0), meta.get("h",0), meta.get("sheetK",data.map_data.get("spriteK",1))]
	Frozen.freeze(result)
	return result

func construction_preview_at(point: Vector2) -> Dictionary:
	var data: Object = _read_live.call()
	if data == null: return {}
	if data.world.world_orders.cmd_pending_kind() != "build": return {}
	var query: Dictionary = data.world.construction_orders.build_placement_at(point, data.cmd_pending_data)
	if query.is_empty(): return {}
	var meta: Dictionary = data.map_data.units.get(str(int(query.unit)), {})
	# Packed arrays remain mutable through a read-only Dictionary. Expose frozen value arrays.
	var result := {"valid":bool(query.valid),"unit":int(query.unit),"anchor":Vector2(query.anchor),
		"reason":str(query.reason),"cells":query.cells.duplicate(),"outline":Array(query.outline),
		"unit_size":Vector2(float(meta.get("w",0)),float(meta.get("h",0))),
		"sprite_k":float(meta.get("sheetK",data.map_data.get("spriteK",1)))}
	result["cell_polygons"] = _preview_cell_polygons(data.nav, result.cells)
	# Whitelist bounded values and freeze owned containers; no deep copy of domain records.
	Frozen.freeze(result)
	return result

func _preview_cell_polygons(navigation: Object, cells: Array) -> Array:
	var result := []
	if navigation == null: return result
	var hw: float = navigation.tile_hw
	var hh: float = navigation.tile_hh
	for cell in cells:
		var point: Vector2 = navigation.anchor_of(cell.x,cell.y)
		var corners := [point+Vector2(0,-hh),point+Vector2(hw,0),point+Vector2(0,hh),point+Vector2(-hw,0)]
		corners.append(corners[0])
		result.append(corners)
	return result

func resource_layer_key(viewport: Rect2) -> Array:
	var data: Object = _read_live.call()
	if data == null: return []
	# Geometry, not blocker version: unrelated gates must not rescan static decor.
	var result := [data.world.get_instance_id(),data.nav.get_instance_id(),data.resource_revision,
		data.nav.geometry_revision,viewport]
	Frozen.freeze(result)
	return result

func resource_layer_projection(viewport: Rect2) -> Array:
	var data: Object = _read_live.call()
	return _resource_projection.visible(data, viewport) if data != null else []

func cell_of_px(px: float, py: float) -> Vector2i:
	var data: Object = _read_live.call()
	return data.world.movement._cell_of_px(px, py) if data != null else Vector2i(-1, -1)
