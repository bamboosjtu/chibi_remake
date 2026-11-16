extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(100).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var mode := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--presentation-case="): mode=argument.substr(20)
	assert(not mode.is_empty(), "Run through tools/test_missing_presentation.mjs")
	if mode=="terrain-budget":
		_terrain_budget()
	else:
		_scene(mode)
	print("PRESENTATION FAILURE PASS ",mode)
	done=true; quit()

func _scene(mode: String) -> void:
	var game: Node = root.get_node("Game"); game.current_map="chibil1"
	var battle = load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode=true; battle.ai=null
	assert(battle.scene.ready_to_save and not battle.units.is_empty())
	battle.view.event_view.restore_history(); battle.view.update_panel()
	var ui = battle.view._ui
	var skin = load("res://presentation/hud/battle_skin.gd").new()
	match mode:
		"panel":
			assert(skin.texture_for("hud_right")==null and skin.texture_for("hud_bar_tile")==null)
			assert(not ui._topbar_original and ui.top_bar.color.a>0 and ui.res_slots.size()==4)
		"controls": assert(skin.texture_for("btn_special")==null and skin.texture_for("btn_next")==null)
		"banner": assert(skin.texture_for("hud_banner")==null)
		"icons": assert(skin.texture_for("res_gold")==null and ui.res_slots.size()==4)
		"minimap-missing", "minimap-invalid", "minimap-entry", "minimap-png":
			var minimap = ui.minimap
			assert(not minimap.terrain_error.is_empty() and minimap.terrain.texture!=null)
			assert(minimap.map_texture.get_size()==Vector2(2,2) and minimap.overlay!=null and minimap.camera_overlay!=null)
		_: assert(false,"Unknown fixture mode")
	assert(battle.view.battle_rect().size.x>0 and battle.view.battle_rect().size.y>0)
	battle.scene.ready_to_save=false; battle.free()

func _terrain_budget() -> void:
	var record := {"rect":[0,0,4,4],"lods":{}}
	for lod in [1,2,4]:
		var image := Image.create(4*lod,4*lod,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE)
		var filename := ProjectSettings.globalize_path("user://budget-%d.png" % lod)
		assert(image.save_png(filename)==OK)
		record.lods[str(lod)]={"texture":filename,"bytes":64*lod*lod}
	var host := Node2D.new()
	var stream = load("res://presentation/battle/terrain_stream.gd").new(host,"__fixture__")
	root.add_child(stream); stream.set_process(false); stream.chunks=[record]; stream.budget=1
	stream.update_visible(Rect2(0,0,4,4))
	assert(not stream.loading_error.is_empty() and stream.active.is_empty() and stream._pending.is_empty() and stream._queued.is_empty())
	stream.budget=128; stream.update_visible(Rect2(0,0,4,4))
	assert(stream.loading_error.is_empty() and stream.active.size()==1 and stream.loaded_bytes==64)
	stream.free()
	stream=load("res://presentation/battle/terrain_stream.gd").new(host,"__fixture__")
	root.add_child(stream); stream.set_process(false); stream.chunks=[record]; stream.budget=128
	for lod in record.lods: record.lods[lod].bytes=1
	stream.update_visible(Rect2(0,0,4,4))
	assert(not stream.loading_error.is_empty() and stream.active.is_empty() and stream.loaded_bytes==0, "Decoded dimensions must override false byte metadata")
	stream.free()
	for lod in record.lods: record.lods[lod].bytes=64*int(lod)*int(lod)
	stream=load("res://presentation/battle/terrain_stream.gd").new(host,"__fixture__")
	root.add_child(stream); stream.set_process(false); stream.chunks=[record]; stream.budget=128
	stream.update_visible(Rect2(0,0,4,4),false)
	assert(not stream._pending.is_empty())
	stream.budget=1; stream.update_visible(Rect2(0,0,4,4),false); stream._finish_requests(true)
	assert(stream.active.is_empty() and stream._pending.is_empty() and stream._queued.is_empty())
	stream.free(); host.free()
