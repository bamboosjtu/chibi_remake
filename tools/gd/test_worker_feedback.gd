extends SceneTree
var done := false
var capture_dir := ""
func _initialize() -> void:
	create_timer(100).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.substr(14)
			DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_node("Game").current_map = "chibil1"
	var b: Node2D = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for unit in b.units: b.commands._cancel_unit_command(unit); unit.hold = true
	var hq: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) == 0)[0]
	var leader: Dictionary = b.selected[0]
	b.view.update_panel() # Cache the grouped panel before selecting a new worker.
	b.selected = [hq]; b.gold = 20000; b.wood = 20000; b.food = 20000
	assert(b.commands._queue_train(b.player_owner, hq, 30))
	b.view.update_panel()
	assert(b.view.cmd_buttons[0].icon != null and b.view.cmd_buttons[0].get_node("ProductionProgress").text == "0%")
	assert(str(b.view.cmd_buttons[0].get_meta("build_hint")).contains("400"), "training hover must include the cost")
	for tick in range(50): b.commands._process_trainings(b.SIM_DT)
	b.view.update_panel()
	assert(b.view.cmd_buttons[0].get_node("ProductionProgress").text == "50%")
	await capture(b, "worker-training")
	var game := root.get_node("Game")
	assert(game.save_game(b.units, b.commands._resources(), b.commands._save_extra()), "save during worker production")
	var saved: Dictionary = game.load_save()
	assert(saved.has("checksum") and game.verify_save_checksum(saved))
	for tick in range(50): b.commands._process_trainings(b.SIM_DT)
	var worker: Dictionary = b.units.back()
	assert(int(worker.unit) == 30 and int(worker.group_officer) < 0 and b.feedback_text.contains("训练完成"))
	b.selected = [worker]; b.view.update_panel()
	assert(b.view._panel_specs().map(func(sp): return str(sp.cmd)) == ["move", "form", "join", "board"])
	for i in range(4): assert(b.view.art_buttons[i].btn.visible)
	assert(not b.view.art_buttons[4].btn.visible)
	assert(b.view.art_buttons[1].btn.get_meta("cmd_name") == "组建" and b.view.art_buttons[2].btn.get_meta("cmd_name") == "加入", "panel cache must refresh grouped -> independent")
	assert(b.view.art_buttons[1].btn.texture.resource_path.ends_with("command-form-v1.svg"))
	await capture(b, "independent-worker")
	# Cargo state, not combat action, selects the existing wheelbarrow frames.
	for kind in ["wood", "stone", "food"]:
		worker.carry = 200.0; worker.carry_kind = kind; worker.state = "deliver"; worker.moved = true
		b.commands._update_visual(worker)
		var clip: String = {"wood":"act1", "stone":"act2", "food":"act3"}[kind]
		assert(b.commands._clip_dir(worker, clip, int(worker.dir) & 7).any(func(frame): return int(frame) == int(b.view.unit_nodes(worker).frame)), "cargo %s must display its wheelbarrow clip" % kind)
		await capture(b, "worker-cart-" + kind)
	worker.carry = 0.0; worker.carry_kind = ""
	assert(b.commands._order_join(leader) == 1)
	for tick in range(2500):
		b.commands._step_unit(worker, b.SIM_DT)
		if int(worker.group_officer) >= 0: break
	assert(int(worker.group_officer) == int(leader.officer.index) and b.commands.control_group_size(1) == 6, "join must reach the commander and update the existing slot")
	b.view.update_panel()
	assert(b.view.art_buttons[6].btn.get_meta("cmd_name") == "解散", "independent -> grouped refresh")
	# JSON number normalization must retain integrity checks for large integers.
	var extra: Dictionary = b.commands._save_extra()
	extra.simulation.officerProgress["precision_probe"] = 9007199254740993
	assert(game.save_game(b.units, b.commands._resources(), extra), "save after joining and training")
	saved = game.load_save()
	assert(saved.has("checksum") and game.verify_save_checksum(saved))
	assert(b.saver.apply_snapshot(saved), "saved worker production and team state must reload")
	print("WORKER FEEDBACK PASS production icon/progress/cost / four independent commands / live panel refresh / cart clips / join+slot / checked save roundtrip")
	b.free(); done = true; quit()

func capture(b: Node2D, name: String) -> void:
	if capture_dir == "": return
	var selected: Dictionary = b.selected[0]
	var focus := Vector2(selected.ax,selected.ay-20)
	b.cam.zoom = Vector2.ONE * 2.0
	b.cam.position = focus - (b.view.battle_rect().get_center()-root.get_visible_rect().size*.5)/b.cam.zoom
	b.view.clamp_camera(); b.cam.force_update_scroll(); b.view.update_panel(); b.view.update_hud_text()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK)
