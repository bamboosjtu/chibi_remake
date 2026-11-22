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
	await process_frame; await process_frame
	var leader: Dictionary = b.selected[0]
	var worker: Dictionary = b.units.filter(func(u): return int(u.unit) == 30 and int(u.get("group_officer", -1)) == int(leader.officer.index))[0]
	b.selected = [worker]; worker.carry = 0
	await capture("worker-member")
	var panel = b.view.classic_panel
	assert(panel.captions[0].text == "归属" and panel.values[0].text == str(leader.officer.name).replace(" ", ""))
	assert(b.view.art_buttons[3].btn.visible and b.view.art_buttons[3].btn.get_meta("command_id") == 16146)
	assert(_verify_mine_stock(worker))
	assert(b.world.entity_factory._spawn_unit(23, b.player_owner, 1000, 1600, true))
	var bank: Dictionary = b.units.back()
	b.gold = 100000; b.wood = 100000; b.food = 100000; b.stone = 100000
	b.selected = [bank]
	await capture("bank-idle")
	assert(b.view.cmd_capsules.size() == 6)
	for i in range(6): assert(b.view.cmd_buttons[i].visible and b.view.cmd_buttons[i].icon != null and b.view.cmd_buttons[i].text == "")
	assert(is_equal_approx(b.view.cmd_buttons[0].position.y, b.view.cmd_buttons[2].position.y))
	assert(b.world.technology._start_tech(12))
	for tick in range(80): b.world.technology._process_tech(b.SIM_DT)
	await capture("bank-selling")
	assert(panel.work_icon.visible and panel.progress_bar.visible and panel.progress_bar.value == 40)
	assert(b.view.cmd_capsules.size() == 1 and b.view.cmd_buttons[0].icon != null)
	b.view.command_actions._on_cmd(0); b.player_commands.apply_tick(b.sim_tick + 1)
	assert(not b.world.technology.tech_research_active())
	var hq: Dictionary = b.units.filter(func(u): return int(u.unit) == 0 and int(u.owner) == b.player_owner)[0]
	b.selected = [hq]; assert(b.world.production._queue_train(b.player_owner, hq, 30))
	b.trainings[0].t = 60
	await capture("hq-training")
	assert(panel.work_icon.visible and panel.work_badge.text == "100人" and panel.progress_bar.value == 40)
	assert(b.view.cmd_capsules.size() == 1)
	assert(panel.work_icon.texture == b.remaster_art.recruitment_portrait(30))
	b.world.production._cancel_training(hq)
	if not (await _verify_recruitment_portraits(hq)):
		quit(1)
		return
	assert(b.world.entity_factory._spawn_unit(12, b.player_owner, 1050, 1600, true))
	var barracks: Dictionary = b.units.back()
	b.selected = [barracks]; assert(b.world.production._queue_train(b.player_owner, barracks, 32))
	b.trainings[0].t = 50
	await capture("barracks-training")
	assert(panel.work_icon.visible and panel.work_badge.text == "100人" and panel.progress_bar.value == 50)
	b.world.production._cancel_training(barracks)
	assert(b.world.entity_factory._spawn_unit(18, b.player_owner, 1100, 1600, true))
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

func _verify_mine_stock(worker: Dictionary) -> bool:
	var mines: Array = b.units.filter(func(u): return int(u.unit) == 22)
	assert(mines.size() == 2)
	for mine in mines:
		b.selected = [mine]
		b.view.update_panel()
		assert(mine.stock == 50000 and mine.map_object)
		assert(b.view.classic_panel.values[3].text == "50000")
		assert(b.view.classic_panel.values[4].text == "可采集")
	var target: Dictionary = mines[0]
	b.selected = [target]
	b.view.update_panel()
	worker.gather_ticks = 99
	b.harvesting.extract(worker, target)
	b.view.update_panel()
	assert(worker.carry == 200 and b.view.classic_panel.values[3].text == "49800", "Stock-only changes refresh the selection cache in the same tick")
	worker.carry = 0.0
	worker.carry_kind = ""
	worker.state = "idle"
	var target_uid := int(target.uid)
	var worker_uid := int(worker.uid)
	var game := root.get_node("Game")
	assert(game.save_game(b.units, b.world.economy.player_resources(), b.scene_controller._save_extra()))
	assert(b.saver.apply_snapshot(game.load_save()))
	target = b.units.filter(func(u): return int(u.uid) == target_uid)[0]
	worker = b.units.filter(func(u): return int(u.uid) == worker_uid)[0]
	b.selected = [target]
	b.view.update_panel()
	assert(target.stock == 49800 and b.view.classic_panel.values[3].text == "49800")
	target.stock = 200.0
	worker.gather_ticks = 99
	b.harvesting.extract(worker, target)
	assert(target.stock == 0.0 and target.hp == 0.0 and target.die_t >= 0.0)
	assert(worker.carry == 200 and worker.carry_kind == "stone")
	print("LIU MINE PANEL PASS two fresh mines / stock reflected after extraction / save-and-load / depletion")
	return true

func _verify_recruitment_portraits(hq: Dictionary) -> bool:
	var separate_regions := {}
	var cases := [[0, [30]], [6, [36,37]], [12, [32,38,41,43]], [14, [45,39,42,44]]]
	var tier: int = int(b.player_tech.level)
	for sample in cases:
		var building := hq
		var bid: int = sample[0]
		var ids: Array = sample[1]
		if bid != 0:
			assert(b.world.entity_factory._spawn_unit(bid, b.player_owner, 1150 + bid*44, 1550, true))
			building = b.units.back()
		b.selected = [building]
		await capture("recruitment-%d-tier-1" % bid)
		var portrait: AtlasTexture = b.remaster_art.recruitment_portrait(ids[0])
		assert(portrait != null and b.view.cmd_buttons[0].icon == portrait)
		assert(b.view.cmd_capsules.filter(func(spec): return bool(spec.get("production", false))).size() == 1, "first tier still exposes just its original single recruit")
		assert(not separate_regions.has(portrait.region), "each troop family needs its own artwork")
		separate_regions[portrait.region] = true
		b.player_tech.level = 1 if bid == 6 else 3
		await capture("recruitment-%d-full" % bid)
		for i in range(ids.size()):
			var variant: Texture2D = b.remaster_art.recruitment_portrait(ids[i])
			assert(b.view.cmd_buttons[i].icon == variant)
			assert(b.view.cmd_capsules[i].progress_label.begins_with(str([100,200,500,1000][i])))
		if bid == 6:
			var button: Button = b.view.cmd_buttons[1]
			var gold: float = b.gold
			b.gold = 0
			await capture("recruitment-6-unaffordable")
			assert(button.visible and button.disabled and button.get_theme_color("icon_disabled_color").r < 0.6)
			b.view.command_actions._on_cmd(1)
			assert(b.player_commands.apply_tick(b.sim_tick + 1) == 0)
			b.gold = gold
			await capture("recruitment-6-available")
			b.view.command_actions._on_cmd(1)
			assert(b.player_commands.apply_tick(b.sim_tick + 1) == 1)
			await capture("recruitment-6-training")
			assert(b.view.classic_panel.work_icon.texture == b.remaster_art.recruitment_portrait(37))
			assert(b.view.classic_panel.work_badge.text.begins_with("200"))
			b.world.production._cancel_training(building)
		b.player_tech.level = tier
	assert(b.remaster_art.recruitment_portrait(34) == null and b.remaster_art.recruitment_portrait(40) == null)
	print("RECRUITMENT PORTRAITS PASS distinct worker/cavalry/infantry/bow portraits / original tiers / disabled / active training")
	return true
