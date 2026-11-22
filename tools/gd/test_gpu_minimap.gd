extends SceneTree
func _initialize():
	create_timer(120).timeout.connect(func():quit(1))
	if DisplayServer.get_name()=="headless":
		push_error("GPU minimap acceptance requires a real rendering window");quit(1);return
	run.call_deferred()
func run():
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map="chibic17"
	var battle=load("res://main.tscn").instantiate();root.add_child(battle);battle.set_process(false)
	var driver=load("res://testing/benchmark/full_battle_benchmark.gd").new();driver.target_units=660;driver.engage=240;driver._fill(battle);driver.free()
	var minimap=battle.view._ui.minimap
	for i in range(30):await process_frame
	var game: Node=root.get_node("Game")
	var checksum: String=game.save_checksum(battle.saver.continuation_snapshot(game))
	var samples: Array=[]
	for gpu in [false,true]:
		minimap.gpu_markers=gpu;minimap.queue_redraw()
		for i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var result:=root.get_texture().get_image().get_region(Rect2i(minimap.get_global_rect()))
		samples.append(result);result.save_png(OS.get_environment("LOCALAPPDATA").path_join("gpu-markers.png" if gpu else "cpu-markers.png"))
	var changed:=0;var max_delta:=0.;var total:=0.
	for y in range(samples[0].get_height()):
		for x in range(samples[0].get_width()):
			var a: Color=samples[0].get_pixel(x,y);var b: Color=samples[1].get_pixel(x,y)
			var d:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			if d>0:changed+=1
			max_delta=maxf(max_delta,d);total+=d
	print("GPU MAP COMPARE ",JSON.stringify({"changed":changed,"max":max_delta,"mean":total/(samples[0].get_width()*samples[0].get_height()),"instances":minimap.marker_mesh.multimesh.visible_instance_count,"simTick":battle.sim_tick}))
	assert(checksum==game.save_checksum(battle.saver.continuation_snapshot(game)),"Rendering changed simulation state")
	assert(max_delta<=1.01/255.,"GPU marker pixels differ from reference")
	battle.scene.ready_to_save=false;battle.free();print("GPU MINIMAP PASS same marker pixels / ordering / camera outline / frozen simulation");quit()
