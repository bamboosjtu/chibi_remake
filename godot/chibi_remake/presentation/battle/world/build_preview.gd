extends Node2D
## Preview is a view of the exact placement query; it never creates a simulation unit.
var host: Node2D
var ghost: Sprite2D
var kind := -1
var placement: Dictionary = {}
var signature: Array = []
var _appearance: Array = []
var projection_builds := 0
var _outline := PackedVector2Array()
var _border := PackedVector2Array()
var _cell_polygons: Array = []

func _init(battle: Node2D) -> void:
	host = battle; z_index = 4001; visible = false

func _process(_delta: float) -> void:
	update_at(get_global_mouse_position(), host.view.hud_metrics.battle_rect.has_point(get_viewport().get_mouse_position()))

func update_at(world: Vector2, on_battle := true) -> void:
	var key: Array = host.queries.map.construction_preview_key(world) if on_battle else []
	if key.is_empty():
		visible = false; signature = []; placement = {}; return
	if key == signature: return
	signature = key
	placement = host.queries.map.construction_preview_at(world)
	projection_builds += 1
	if placement.is_empty(): visible = false; return
	var bid := int(placement.unit)
	var size: Vector2 = placement.unit_size
	if size.x <= 0 or size.y <= 0: visible = false; return
	visible = true
	var appearance := [bid, size, placement.sprite_k]
	if ghost == null or _appearance != appearance:
		if ghost != null: ghost.free()
		ghost = Sprite2D.new(); ghost.centered = false; add_child(ghost)
		var k := float(placement.sprite_k)
		ghost.scale = Vector2.ONE / k
		host.remaster_art.create_unit_skin(ghost, bid, 0, Vector2i(int(size.x*k),int(size.y*k)))
		kind = bid
		_appearance = appearance
	ghost.position = placement.anchor - Vector2(size.x*0.5,size.y)
	ghost.modulate = Color(0.45, 1.0, 0.5, 0.55) if placement.valid else Color(1.0, 0.3, 0.25, 0.55)
	_outline = PackedVector2Array(placement.outline)
	_border = _outline.duplicate()
	if not _border.is_empty(): _border.append(_border[0])
	_cell_polygons = placement.cell_polygons.map(func(points): return PackedVector2Array(points))
	queue_redraw()

func _draw() -> void:
	if placement.is_empty(): return
	var color := Color(0.2, 1.0, 0.3) if placement.valid else Color(1.0, 0.2, 0.15)
	if _outline.size() < 3: return
	draw_colored_polygon(_outline, Color(color, 0.22))
	for polygon in _cell_polygons:
		draw_polyline(polygon, Color(color, 0.35), 0.7)
	draw_polyline(_border, color, 1.6)
