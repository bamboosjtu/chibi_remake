extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	assert("--no-intro" in OS.get_cmdline_user_args(),"capture requires --no-intro so video cannot cover the evidence")
	root.get_node("Game").current_map = "chibil1"
	var b: Node2D = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var output := "user://gate-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	var worker: Dictionary = b.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == b.player_owner)[0]
	var gates: Array = b.units.filter(func(u): return int(u.unit) in [16,17])
	var terrain: Node2D
	for child in b.view.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("terrain_stream.gd"): terrain = child
	for i in range(gates.size()):
		var gate: Dictionary = gates[i]
		for opened in [false,true]:
			worker.ax = float(gate.ax) + 22; worker.ay = float(gate.ay) - (33 if opened else 143)
			worker.state = "move" if opened else "idle"
			worker.path = [Vector2(gate.ax,gate.ay)] if opened else []
			worker.pi = 0
			b.commands._place_unit(worker); b.commands._update_gates()
			assert(bool(gate.gate_open) == opened)
			b.visibility.update(b.units,b.player_owner)
			b.selected = []; b.cam.zoom = Vector2.ONE * 2.5
			var focus := Vector2(gate.ax,gate.ay-33)
			b.cam.position = focus - (b.view.battle_rect().get_center()-root.get_visible_rect().size*.5)/b.cam.zoom
			b.view.clamp_camera(); b.cam.force_update_scroll()
			for unit in b.units: b.commands._update_visual(unit)
			if "--bare-walls" in OS.get_cmdline_user_args():
				b.view.unit_nodes(gate).skin.visible = false
				b.view.unit_nodes(gate).gate_module.visible = false
				b.view.unit_nodes(gate).gate_interior.visible = false
			print("ANCHOR ",i," ",gate.ax,"/",gate.ay," sprite=",b.view.unit_nodes(gate).spr.position)
			b.view.update_panel(); b.view.update_hud_text()
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			if opened and "--bare-walls" not in OS.get_cmdline_user_args():
				# Verify the actual GPU terrain shader removes wall pixels, while
				# neighboring bricks keep precisely their original color.
				b.view.unit_nodes(gate).gate_module.visible = false
				var count := int(terrain.gate_material.get_shader_parameter("gate_count"))
				terrain.gate_material.set_shader_parameter("gate_count",0)
				await process_frame; await RenderingServer.frame_post_draw
				var solid := root.get_texture().get_image()
				terrain.gate_material.set_shader_parameter("gate_count",count)
				await process_frame; await RenderingServer.frame_post_draw
				var cut := root.get_texture().get_image()
				var module: Node2D = b.view.unit_nodes(gate).gate_module
				var polygon: PackedVector2Array = module.aperture
				var center: Vector2 = (polygon[0]+polygon[2])*0.5
				var xform := module.get_global_transform_with_canvas()
				var inside := Vector2i(xform*center)
				var outside := Vector2i(xform*(polygon[0]-Vector2(4,0)))
				assert(solid.get_pixelv(inside) != cut.get_pixelv(inside),"open aperture must actually cut the terrain wall")
				assert(solid.get_pixelv(outside).is_equal_approx(cut.get_pixelv(outside)),"wall texture outside the opening must remain unchanged")
				b.view.unit_nodes(gate).gate_module.visible = true
				await process_frame; await RenderingServer.frame_post_draw
				print("GATE TERRAIN CUTOUT PASS ",i," wall removed inside / neighboring bricks unchanged")
			var path := output.path_join("gate-%d-%d-%s.png" % [int(gate.unit),i,"open" if opened else "closed"])
			assert(root.get_texture().get_image().save_png(path) == OK)
	print("GATE CAPTURE PASS all four wall openings, both states")
	b.free(); quit()
