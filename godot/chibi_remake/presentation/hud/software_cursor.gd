extends CanvasLayer
const Textures = preload("res://presentation/battle/runtime_textures.gd")
const Metrics = preload("res://presentation/hud/hud_metrics.gd")
var data: Dictionary
var sprite: Sprite2D
var textures := {}
var bank := "C"
var row := 0
var column := 0
var elapsed := 0.0

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/cursors.json"))
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)

func _exit_tree() -> void: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var pointer := get_viewport().get_mouse_position()
	var viewport := get_viewport().get_visible_rect()
	if not get_window().has_focus() or not viewport.has_point(pointer):
		sprite.hide();Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var host := _battle()
	if host != null and host.selecting and not get_tree().paused:
		var rect: Rect2 = host.view.battle_rect()
		var clamped := pointer.clamp(rect.position,rect.end-Vector2.ONE)
		if clamped != pointer: Input.warp_mouse(get_viewport().get_final_transform()*clamped);pointer=clamped
	draw_at(host,pointer,delta)

## Shared renderer also supports deterministic GPU captures without taking desktop focus.
func draw_at(host: Node2D, pointer: Vector2, delta := 0.0) -> void:
	var viewport:=get_viewport().get_visible_rect()
	var state := resolve(host,pointer)
	advance(delta,state)
	if _video_playing(): sprite.hide();return
	sprite.show()
	var index := ["A","B","C"].find(bank)
	var entry: Dictionary = data.banks[index]
	if not textures.has(bank): textures[bank] = Textures.load_texture(data.runtimeTextures[bank],ResourceLoader.CACHE_MODE_REUSE,"formal")
	sprite.texture = textures[bank]
	var row_index := row if bank!="C" else 0
	var boundaries: Array=data.sourceRows[bank]
	var y: float=boundaries[row_index]
	var cell := Vector2(float(sprite.texture.get_width())/float(entry.columns),float(boundaries[row_index+1])-y)
	sprite.region_rect = Rect2(Vector2(column*cell.x,y),cell)
	var scale_factor: float = host.view.ui_scale if host != null else minf(viewport.size.x/640.0,viewport.size.y/480.0)
	sprite.scale = Vector2(entry.cell[0],entry.cell[1])*scale_factor/cell
	var hotspot: Array = entry.hotspots[row]
	sprite.position = pointer-Vector2(hotspot[0],hotspot[1])*scale_factor

func resolve(host: Node2D, pointer: Vector2) -> Dictionary:
	if host == null or host.view == null: return {"bank":"C","row":0}
	var view: Node2D = host.view
	if get_tree().paused or view.battle_menu.is_open: return {"bank":"A","row":0}
	var direction: Vector2 = view.edge_direction(pointer)
	if direction != Vector2.ZERO and not bool(host.selecting):
		var camera := view.cam as Camera2D
		var wanted := camera.position+direction*4
		var clamped := Metrics.clamp_world_pos(wanted,Vector2(host.map_data.terrainW,host.map_data.terrainH),view.battle_rect(),get_viewport().get_visible_rect().size,camera.zoom)
		if not clamped.is_equal_approx(camera.position):
			var directions := [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),Vector2(-1,0)]
			return {"bank":"B","row":directions.find(direction)}
	if not view.battle_rect().has_point(pointer): return {"bank":"A","row":0}
	if host.selecting: return {"bank":"A","row":7}
	var point: Vector2 = host.get_canvas_transform().affine_inverse()*pointer
	var hit: Dictionary = host.commands._hover_unit(point)
	var mode: String = host.commands.cmd_pending_kind()
	var result := 0
	match mode:
		"attack":
			result = 1
			var target: Dictionary=host.commands._attack_target_at(point)
			if not target.is_empty():
				result = 3
				if int(target.owner)==0 and not host.commands._selected_has_nonworker_attacker(): result=2
			elif not hit.is_empty(): result=2
		"transport":
			result = 4
			if not host.commands._resource_at(point).is_empty() or not host.commands._resource_at(point+Vector2(0,15)).is_empty(): result=5
		"join":
			result = 8
			var own: Dictionary = host.commands._own_object_at(point)
			if not own.is_empty() and not host.commands._commander_for(own).is_empty(): result=9
		_: result = 6 if not hit.is_empty() else 0
	return {"bank":"A","row":result}

func advance(delta: float, state: Dictionary) -> void:
	if bank != str(state.bank) or row != int(state.row):
		bank=state.bank;row=int(state.row);column=0;elapsed=0.0
	if bank == "B": column=0;return
	elapsed += delta
	while elapsed >= 0.160:
		elapsed -= 0.160;column=(column+1)%4

func _battle() -> Node2D:
	for child in get_tree().root.get_children():
		if child is Node2D and child.get_script() != null and child.get_script().resource_path == "res://main.gd" and child.view != null: return child
	return null

func _video_playing() -> bool:
	for player in get_tree().root.find_children("*","VideoStreamPlayer",true,false):
		if player.is_playing(): return true
	return false
