extends SceneTree
var done := false
var b: Node2D

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	root.get_node("Game").current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for u in b.units: b.commands.military._cancel_unit_command(u); u.hold = true
	var workers: Array = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 30)
	var captain: Dictionary = b.commands.military._commander_for(workers[0])
	var ungrouped_worker: Dictionary = workers[0].duplicate()
	ungrouped_worker.group_officer = -1; ungrouped_worker.officer = {}
	b.selected = [ungrouped_worker]
	var worker_specs: Array = b.view._panel_specs()
	assert(worker_specs.map(func(sp): return str(sp.get("cmd", ""))) == ["move", "form", "join", "board"])
	b.selected = [captain]
	var preview_unit := 10
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-unit="): preview_unit = int(arg.substr(15))
	var option: Dictionary = b.build_types.filter(func(o): return int(o.unit) == preview_unit)[0]
	var origin: Vector2i = b.commands.world._unit_cell(captain)
	var chosen: Dictionary = {}
	for r in range(3, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var point: Vector2 = b.nav.anchor_of(origin.x + dx, origin.y + dy)
				var query: Dictionary = b.commands.economy.build_placement_at(point, option)
				if query.valid: chosen = query; break
			if not chosen.is_empty(): break
		if not chosen.is_empty(): break
	assert(not chosen.is_empty())
	b.commands.military._cmd_begin("build", option)
	var before: Dictionary = b.commands.world._resources().duplicate()
	var count: int = b.units.size(); var uid: int = b.next_uid
	b.view.construction_preview.update_at(chosen.anchor)
	assert(b.view.construction_preview.visible and b.view.construction_preview.placement.valid)
	assert(b.view.construction_preview.placement.outline.size() == 4)
	assert(b.view.construction_preview.ghost.get_child_count() > 0)
	assert(b.units.size() == count and b.next_uid == uid and b.commands.world._resources() == before)
	if "--capture-feedback" in OS.get_cmdline_user_args():
		b.view.construction_preview.set_process(false)
		b.cam.zoom = Vector2(2, 2)
		b.cam.position = chosen.anchor - (b.view.battle_rect().get_center() - root.get_visible_rect().size * 0.5) / b.cam.zoom
		b.cam.force_update_scroll(); b.commands.session._view_hud()
		await process_frame; await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://build-preview-valid.png")
	var hq: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) == 0)[0]
	b.view.construction_preview.update_at(Vector2(hq.ax, hq.ay))
	assert(not b.view.construction_preview.placement.valid)
	b.commands.orders._resolve_pending(Vector2(hq.ax, hq.ay))
	assert(b.commands.orders.cmd_pending_kind() == "build" and b.units.size() == count and b.commands.world._resources() == before)
	b.commands.orders._resolve_pending(chosen.anchor)
	assert(b.commands.orders.cmd_pending_kind() == "" and b.units.size() == count + 1)
	var site: Dictionary = b.units.back()
	assert(Vector2(site.ax, site.ay).is_equal_approx(chosen.anchor) and site.occupied_cells == chosen.cells)
	b.view.construction_preview.update_at(chosen.anchor)
	assert(not b.view.construction_preview.visible)
	for tick in range(3000):
		for u in [captain] + workers: b.commands.orders._step_unit(u, b.SIM_DT)
		if ([captain] + workers).all(func(u): return int(u.site_inside_uid) == int(site.uid)): break
	assert(([captain] + workers).all(func(u): return int(u.site_inside_uid) == int(site.uid)), "whole crew must enter")
	assert(b.commands.military.control_group_size(1) == 5 and int(b.commands.military.control_group_work_site(1).uid) == int(site.uid), "construction must retain the team slot")
	b.view.update_panel()
	assert(not b.view.hot_buttons[0].btn.disabled and b.view.hot_buttons[0].work_badge.visible, "the working crew remains visible and recallable")
	for u in [captain] + workers:
		assert(not b.view.unit_nodes(u).spr.visible and not b.commands.world._index_eligible(u))
		assert(b.commands.orders._player_at(Vector2(u.ax, u.ay - u.h * 0.5)) != u)
	var old_hp: float = site.hp
	for tick in range(4):
		for w in workers: b.commands.orders._step_unit(w, b.SIM_DT)
	assert(site.hp == old_hp + 2 * workers.size())
	var crew_ids: Array = workers.map(func(u): return int(u.uid))
	var captain_uid := int(captain.uid); var site_uid := int(site.uid)
	var game: Node = root.get_node("Game")
	assert(game.save_game(b.units, b.commands.world._resources(), b.commands.session._save_extra()))
	assert(b.saver.apply_snapshot(game.load_save()))
	workers = b.units.filter(func(u): return int(u.uid) in crew_ids)
	captain = b.units.filter(func(u): return int(u.uid) == captain_uid)[0]
	site = b.units.filter(func(u): return int(u.uid) == site_uid)[0]
	for u in [captain] + workers:
		assert(int(u.site_inside_uid) == site_uid and not b.view.unit_nodes(u).spr.visible)
		assert(Vector2(u.ax, u.ay).is_equal_approx(Vector2(site.ax, site.ay)))
	# A blocked doorway retains the worker and retries after space opens.
	var blocked: Array = []
	var entry: Vector2i = b.nav.cell_of_px(workers[0].site_entry_x, workers[0].site_entry_y)
	for dx in range(-12, 13):
		for dy in range(-12, 13):
			var cell := entry + Vector2i(dx, dy)
			if not b.nav.is_solid(cell): b.nav.block(cell); blocked.append(cell)
	b.commands.military._cancel_unit_command(workers[0])
	assert(workers[0].site_exit_pending and int(workers[0].site_inside_uid) == site_uid)
	for cell in blocked: b.nav.unblock(cell)
	b.commands.orders._step_unit(workers[0], b.SIM_DT)
	assert(int(workers[0].site_inside_uid) < 0 and b.view.unit_nodes(workers[0]).spr.visible)
	assert(b.commands.economy._assign_build_worker(workers[0], site))
	for tick in range(200):
		b.commands.orders._step_unit(workers[0], b.SIM_DT)
		if int(workers[0].site_inside_uid) == site_uid: break
	assert(int(workers[0].site_inside_uid) == site_uid)
	if "--capture-feedback" in OS.get_cmdline_user_args():
		b.commands.economy._process_sites(b.SIM_DT); b.commands.world._update_visual(site); b.selected = [site]; b.commands.session._view_hud()
		b.cam.position = chosen.anchor; b.cam.zoom = Vector2(2, 2)
		await process_frame; await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://construction-inside.png")
		b.selected = [captain]; b.commands.military._cmd_begin("build", option)
		b.view.construction_preview.set_process(false)
		b.view.construction_preview.update_at(chosen.anchor + Vector2(220, 0))
		await process_frame; await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://build-preview.png")
		b.commands.orders._clear_pending()
	b.commands.economy._complete_site(site)
	for u in [captain] + workers:
		assert(int(u.site_inside_uid) < 0 and b.view.unit_nodes(u).spr.visible)
		assert(b.commands.world._unit_placement_free(b.commands.world._unit_cell(u), int(u.unit), b.commands.military._nav_layer(u), int(u.uid)))
	print("BUILD FEEDBACK PASS exact preview / invalid retry / no preview mutation / crew entry / hidden untargetable / physical work / save inside / blocked exit retry / safe exit")
	b.free(); done = true; quit()
