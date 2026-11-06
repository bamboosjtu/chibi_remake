extends SceneTree
## 从可见精灵区域发鼠标事件，验证镜头变换、旧待选命令和真实装货/入库。
var done := false
var battle: Node2D
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func click_at(point: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point * root.get_final_transform().get_scale()
		event.global_position = event.position
		event.button_index = button; event.pressed = pressed
		root.push_input(event, false)
	battle.player_commands.pump()
	battle.view.update_panel()
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	for phase in [0, 2]:
		root.get_node("Game").current_map = "chibil1"
		battle = load("res://main.tscn").instantiate()
		root.add_child(battle)
		load(get_script().resource_path.get_base_dir().path_join("economy_fixture.gd")).warehouses(battle)
		battle.set_process(false); battle.cli_mode = true
		await process_frame; await process_frame
		battle.view.event_view.restore_history()
		var workers: Array = battle.units.filter(func(w): return int(w.unit) == 30 and int(w.owner)==battle.player_owner)
		var origin := Vector2(workers[0].ax, workers[0].ay)
		var targets: Array = battle.decor_targets.filter(func(o): return int(o.phase) == phase)
		targets.sort_custom(func(a,b): return origin.distance_squared_to(Vector2(a.ax,a.ay)) < origin.distance_squared_to(Vector2(b.ax,b.ay)))
		var target: Dictionary = targets[0]
		var frame: Dictionary = battle.remaster_art.runtime_info("resource-decor").frames[phase]
		var draw: Array = frame.draw
		var point := Vector2(target.ax, target.ay) - Vector2(22,60) + Vector2(draw[0]+draw[2]*0.5, draw[1]+draw[3]*0.5)
		battle.cam.position = point - (battle.view.battle_rect().get_center() - root.get_visible_rect().size*0.5) / battle.cam.zoom
		battle.view.clamp_camera(); battle.cam.force_update_scroll()
		battle.selected = [battle.selected[0]] # 点击将领也必须派出麾下四名工人。
		battle.commands._cmd_begin("move")
		var screen := battle.get_canvas_transform() * point
		assert(battle.view.battle_rect().has_point(screen))
		click_at(screen, MOUSE_BUTTON_RIGHT)
		assert(battle.commands.cmd_pending_kind() == "")
		var picked: Dictionary = workers[0].gather_obj
		assert(not picked.is_empty() and int(picked.phase) == phase)
		var clicked_patch := {}
		for cell in battle.commands._resource_patch_cells(picked): clicked_patch[cell] = true
		for assigned_worker in workers:
			var assigned: Dictionary = assigned_worker.get("gather_obj", {})
			assert(assigned_worker.state == "gather" and not assigned.is_empty())
			assert(battle.commands._yield_of(int(assigned.unit)) == battle.commands._yield_of(int(picked.unit)))
			var assigned_cell: Vector2i = battle.nav.cell_of_px(float(assigned.ax), float(assigned.ay))
			assert(clicked_patch.has(assigned_cell), "所有工人都应采集被点击的连通资源片")
		var before: Dictionary = battle.commands._resources()
		var kind: String = battle.commands._yield_of(int(picked.unit))
		var loaded := {}; var delivered := {}
		for step in range(18000):
			battle.commands._update_gates()
			for worker in workers:
				var cargo: float = worker.carry
				battle.commands._step_unit(worker, 1.0/30.0)
				if worker.carry > 0: loaded[worker.uid] = true
				if cargo > 0 and worker.carry == 0: delivered[worker.uid] = true
			if delivered.size() == 4: break
		assert(loaded.size() == 4 and delivered.size() == 4, "phase %d loaded %d workers, delivered %d" % [phase, loaded.size(), delivered.size()])
		assert(battle.commands._resources()[kind] - before[kind] >= 800, "必须实际入库，不能只检查命令状态")
		print("RESOURCE INPUT PASS phase=",phase," screen=",screen," cargo+delivery=4 income=",battle.commands._resources()[kind]-before[kind])
		battle.free()
	root.get_node("Game").current_map = "chibil1"
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true
	await process_frame; await process_frame
	battle.view.event_view.restore_history()
	var view: Node2D = battle.view
	for i in range(2):
		click_at(view.art_buttons[i].btn.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		assert(battle.commands.cmd_pending_kind() == ["move", "attack"][i])
	battle.commands._clear_pending()
	click_at(view.art_buttons[3].btn.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	assert(view.build_menu and battle.build_types.size() == 12 and view.cmd_page_count == 2)
	assert(battle.build_types[0].gold == 30 and battle.build_types[0].food == 1000 and battle.build_types[0].stone == 500)
	for page in range(view.cmd_page_count):
		for btn in view.cmd_buttons:
			if btn.visible:
				assert(btn.icon != null and btn.text == "" and view.back_button.visible)
				assert(btn.tooltip_text == "" and str(btn.get_meta("build_hint", "")) != "", "建筑说明统一显示在左下，不重复浮窗")
		if page < view.cmd_page_count-1: click_at(view.cmd_next.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	click_at(view.back_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	assert(not view.build_menu and view.art_buttons[0].btn.visible)
	# 仅选队长，从图标落地粮仓，验证缺失建筑定义确实能生成并由麾下施工。
	battle.selected = [battle.selected[0]]
	var captain: Dictionary = battle.selected[0]
	var builders: Array = battle.commands._construction_workers(captain)
	click_at(view.art_buttons[3].btn.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	click_at(view.cmd_buttons[1].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	assert(battle.commands.cmd_pending_kind() == "build" and int(battle.cmd_pending_data.unit) == 10)
	var before_build: Dictionary = battle.commands._resources()
	var origin: Vector2i = battle.commands._unit_cell(captain)
	var placement: Dictionary = {}
	for r in range(3, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var query: Dictionary = battle.commands.build_placement_at(battle.nav.anchor_of(origin.x + dx, origin.y + dy), battle.cmd_pending_data)
				if query.valid: placement = query; break
			if not placement.is_empty(): break
		if not placement.is_empty(): break
	assert(not placement.is_empty())
	battle.cam.position = placement.anchor - (view.battle_rect().get_center() - root.get_visible_rect().size * 0.5) / battle.cam.zoom
	view.clamp_camera(); battle.cam.force_update_scroll()
	var location: Vector2 = battle.get_canvas_transform() * placement.anchor
	click_at(location, MOUSE_BUTTON_LEFT)
	var sites: Array = battle.units.filter(func(u): return bool(u.get("site", false)) and int(u.unit) == 10 and u.owner == battle.player_owner)
	assert(sites.size() == 1 and battle.gold == before_build.gold-30 and battle.food == before_build.food-200 and battle.wood == before_build.wood-100 and battle.stone == before_build.stone-100)
	assert(builders.size() == 4)
	for worker in builders: assert(worker.state == "build" and worker.build_target == sites[0])
	# 中止后右键已有粮仓工地继续施工；必须优先于“己方粮仓是卸货点”。
	var site: Dictionary = sites[0]
	var paid_build: Dictionary = battle.commands._resources().duplicate()
	battle.selected = [captain]
	for worker in builders: battle.commands._cancel_unit_command(worker)
	for tick in range(16): battle.commands._process_sites(battle.SIM_DT)
	assert(site.hp == 0)
	var site_point := Vector2(site.ax, site.ay - site.h * 0.5)
	battle.cam.position = site_point - (view.battle_rect().get_center() - root.get_visible_rect().size * 0.5) / battle.cam.zoom
	view.clamp_camera(); battle.cam.force_update_scroll()
	var site_screen: Vector2 = battle.get_canvas_transform() * site_point
	assert(view.battle_rect().has_point(site_screen))
	click_at(site_screen, MOUSE_BUTTON_RIGHT)
	assert(builders.all(func(w): return w.state == "build" and w.build_target == site))
	assert(battle.commands._resources() == paid_build)
	# 运输按钮后点击工地复用同一路径，不新增建筑、不扣费。
	for worker in builders: battle.commands._cancel_unit_command(worker)
	view._close_art_sub(); view.update_panel()
	click_at(view.art_buttons[2].btn.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	assert(battle.commands.cmd_pending_kind() == "transport")
	click_at(site_screen, MOUSE_BUTTON_LEFT)
	assert(battle.commands.cmd_pending_kind() == "" and builders.all(func(w): return w.state == "build" and w.build_target == site))
	assert(battle.commands._resources() == paid_build)
	print("CONSTRUCTION INPUT PASS right-click and transport on existing granary site / commander resolves4workers / no second cost")
	for step in range(18000):
		battle.commands._update_gates()
		for worker in builders: battle.commands._step_unit(worker, 1.0/30.0)
		if not bool(sites[0].site): break
	assert(not bool(sites[0].site) and sites[0].hp == sites[0].maxhp)
	# 加入建筑定义不应破坏上一正式版的同关卡存档；未知版本仍必须拒绝。
	var game := root.get_node("Game")
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var snapshot: Dictionary = game.load_save()
	var file := FileAccess.open("res://data/db/registry_compatibility.json", FileAccess.READ)
	var contract: Dictionary = JSON.parse_string(file.get_as_text())
	snapshot.simulation.contentRevision = contract.previous.chibil1
	assert(battle.saver.apply_snapshot(snapshot))
	snapshot.simulation.contentRevision = "unknown"
	assert(not battle.saver.apply_snapshot(snapshot))
	print("BUILD INPUT PASS 12 buildings, HD icons, paging/back, costs; command order move/attack; previous-save compatibility")
	battle.free(); done = true; quit()
