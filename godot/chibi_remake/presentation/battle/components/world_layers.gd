extends RefCounted
## world layers: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/world_layers_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func build_terrain() -> void:
	# Visual streaming must finish while the opening briefing pauses the simulation.
	var fog: Sprite2D=load("res://presentation/battle/battle_fog.gd").new(_ui.host.get.bind("visibility"))
	_ui.fog_sprite=fog
	fog.process_mode=Node.PROCESS_MODE_ALWAYS
	surface.add_child(fog)
	_ui.resource_layer = load("res://presentation/battle/battle_resources.gd").new(_ui.host)
	_ui.resource_layer.process_mode=Node.PROCESS_MODE_ALWAYS
	surface.add_child(_ui.resource_layer)
	var chunk_path := "res://art/full/terrain_chunks/%s/manifest.json" % str(_ui.host.map_id)
	if not FileAccess.file_exists(chunk_path):
		push_error("Missing HD terrain: " + str(_ui.host.map_id))
		return
	var terrain: Node2D=load("res://presentation/battle/terrain_stream.gd").new(_ui.host, str(_ui.host.map_id))
	terrain.process_mode=Node.PROCESS_MODE_ALWAYS
	surface.add_child(terrain)

func build_marquee() -> void:
	_ui.sel_box_fill = ColorRect.new()
	_ui.sel_box_fill.color = Color(0.2, 1.0, 0.2, 0.12)
	_ui.sel_box_fill.visible = false
	_ui.sel_box_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(_ui.sel_box_fill)
	_ui.sel_box_line = Line2D.new()
	_ui.sel_box_line.width = 1.0
	_ui.sel_box_line.default_color = Color(0.2, 1.0, 0.2, 0.8)
	_ui.sel_box_line.visible = false
	surface.add_child(_ui.sel_box_line)

func marquee_hide() -> void:
	if _ui.sel_box_fill != null:
		_ui.sel_box_fill.visible = false
	if _ui.sel_box_line != null:
		_ui.sel_box_line.visible = false

func marquee_update(r: Rect2) -> void:
	if _ui.sel_box_fill != null:
		_ui.sel_box_fill.visible = true
		_ui.sel_box_fill.position = r.position
		_ui.sel_box_fill.size = r.size
	if _ui.sel_box_line != null:
		_ui.sel_box_line.visible = true
		_ui.sel_box_line.points = PackedVector2Array([
			r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y), r.position])
