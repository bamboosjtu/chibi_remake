extends Node2D
## Preview is a view of the exact placement query; it never creates a simulation unit.
var host: Node2D
var ghost: Sprite2D
var kind := -1
var placement: Dictionary = {}
var signature := ""

func _init(battle: Node2D) -> void:
	host = battle; z_index = 4001; visible = false

func _process(_delta: float) -> void:
	update_at(get_global_mouse_position(), host.view.hud_metrics.battle_rect.has_point(get_viewport().get_mouse_position()))

func update_at(world: Vector2, on_battle := true) -> void:
	if host.cmd_pending_kind() != "build" or not on_battle:
		visible = false; signature = ""; return
	visible = true
	var bid := int(host.cmd_pending_data.unit)
	var cell: Vector2i = host.nav.cell_of_px(world.x, world.y)
	var key := "%s/%s/%s/%s/%s/%s/%s" % [bid, cell, host.sim_tick, host.nav.version, host.units.size(), host.selected.map(func(u): return int(u.uid)), host._resources()]
	if key == signature: return
	signature = key
	placement = host.build_placement_at(world, host.cmd_pending_data)
	var meta: Dictionary = host.map_data.units.get(str(bid), {})
	if ghost == null or kind != bid:
		if ghost != null: ghost.free()
		ghost = Sprite2D.new(); ghost.centered = false; add_child(ghost)
		var k := float(meta.get("sheetK", host.map_data.get("spriteK", 1)))
		ghost.scale = Vector2.ONE / k
		host.remaster_art.create_unit_skin(ghost, bid, 0, Vector2i(int(meta.w * k), int(meta.h * k)))
		kind = bid
	ghost.position = placement.anchor - Vector2(float(meta.w) * 0.5, float(meta.h))
	ghost.modulate = Color(0.45, 1.0, 0.5, 0.55) if placement.valid else Color(1.0, 0.3, 0.25, 0.55)
	queue_redraw()

func _draw() -> void:
	if placement.is_empty(): return
	var color := Color(0.2, 1.0, 0.3) if placement.valid else Color(1.0, 0.2, 0.15)
	var outline: PackedVector2Array = placement.outline
	if outline.size() < 3: return
	draw_colored_polygon(outline, Color(color, 0.22))
	for cell in placement.cells:
		var p: Vector2 = host.nav.anchor_of(cell.x, cell.y)
		var hw: float = host.nav.tile_hw; var hh: float = host.nav.tile_hh
		var corners := PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])
		draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), Color(color, 0.35), 0.7)
	var border := outline.duplicate(); border.append(outline[0])
	draw_polyline(border, color, 1.6)
