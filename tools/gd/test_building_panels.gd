extends SceneTree
## Supplied original-game screenshots: member ownership and building work modes.
var b: Node2D
var output := ""
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func capture(label: String) -> void:
	b.view.update_panel()
	b.view.update_hud_text()
	await process_frame
	if output != "" and DisplayServer.get_name() != "headless":
		for frame in range(30): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.substr(9)
	if output != "": DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	root.get_node("Game").current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	b.player_commands.set_process(false)
	await process_frame; await process_frame
	var leader: Dictionary = b.selected[0]
	var worker: Dictionary = b.units.filter(func(u): return int(u.unit) == 30 and int(u.get("group_officer", -1)) == int(leader.officer.index))[0]
	b.selected = [worker]; worker.carry = 0
	await capture("worker-member")
	var panel = b.view.classic_panel
	assert(panel.captions[0].text == "归属" and panel.values[0].text == str(leader.officer.name).replace(" ", ""))
	assert(b.view.art_buttons[3].btn.visible and b.view.art_buttons[3].btn.get_meta("command_id") == 16146)
	assert(b.commands.world._spawn_unit(23, b.player_owner, 1000, 1600, true))
	var bank: Dictionary = b.units.back()
	b.gold = 100000; b.wood = 100000; b.food = 100000; b.stone = 100000
	b.selected = [bank]
	await capture("bank-idle")
	assert(b.view.cmd_capsules.size() == 6)
	for i in range(6): assert(b.view.cmd_buttons[i].visible and b.view.cmd_buttons[i].icon != null and b.view.cmd_buttons[i].text == "")
	assert(is_equal_approx(b.view.cmd_buttons[0].position.y, b.view.cmd_buttons[2].position.y))
	assert(b.commands.technology._start_tech(12))
	for tick in range(80): b.commands.technology._process_tech(b.SIM_DT)
	await capture("bank-selling")
	assert(panel.work_icon.visible and panel.progress_bar.visible and panel.progress_bar.value == 40)
	assert(b.view.cmd_capsules.size() == 1 and b.view.cmd_buttons[0].icon != null)
	b.view._on_cmd(0); b.player_commands.pump()
	assert(not b.commands.technology.tech_research_active())
	var hq: Dictionary = b.units.filter(func(u): return int(u.unit) == 0 and int(u.owner) == b.player_owner)[0]
	b.selected = [hq]; assert(b.commands.economy._queue_train(b.player_owner, hq, 30))
	b.trainings[0].t = 60
	await capture("hq-training")
	assert(panel.work_icon.visible and panel.work_badge.text == "100人" and panel.progress_bar.value == 40)
	assert(b.view.cmd_capsules.size() == 1)
	b.commands.economy._cancel_training(hq)
	assert(b.commands.world._spawn_unit(12, b.player_owner, 1050, 1600, true))
	var barracks: Dictionary = b.units.back()
	b.selected = [barracks]; assert(b.commands.economy._queue_train(b.player_owner, barracks, 32))
	b.trainings[0].t = 50
	await capture("barracks-training")
	assert(panel.work_icon.visible and panel.work_badge.text == "100人" and panel.progress_bar.value == 50)
	b.commands.economy._cancel_training(barracks)
	assert(b.commands.world._spawn_unit(18, b.player_owner, 1100, 1600, true))
	var site: Dictionary = b.units.back(); site.site = true; site.hp = site.maxhp * 0.25
	b.selected = [site]
	for dimensions in [Vector2i(640,480), Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = dimensions; await process_frame
		await capture("construction-%d" % dimensions.x)
		assert(panel.progress_bar.visible and panel.progress_bar.value == 25 and not panel.work_icon.visible)
		assert(b.view.right_panel.get_global_rect().encloses(panel.progress_bar.get_global_rect()))
		assert(b.view.right_panel.get_global_rect().encloses(b.view.cmd_buttons[0].get_global_rect()))
	print("BUILDING PANELS PASS member ownership / empty return / sale icons / sale cancel / training badge / construction progress /640-1920")
	done = true; quit()
