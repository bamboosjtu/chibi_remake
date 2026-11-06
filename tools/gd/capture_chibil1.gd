extends SceneTree
## 真正的引擎渲染截图；不依赖鼠标位置，不推进开局模拟。
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map = "chibic13" if "--transport-menu" in OS.get_cmdline_user_args() else "chibil1"
	var surface: Viewport = root
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture-size="):
			var parts := a.substr(15).split("x")
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	var battle: Node2D = load("res://main.tscn").instantiate()
	surface.add_child(battle)
	battle.set_process(false); battle.cli_mode = true
	await process_frame
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-zoom="): battle.cam.zoom = Vector2.ONE * float(arg.substr(15))
	if "--transport-menu" in OS.get_cmdline_user_args():
		var pair: Array=[];var best:=INF
		var center:=Vector2(float(battle.map_data.terrainW)*0.5,float(battle.map_data.terrainH)*0.5)
		for a in range(6,int(battle.map_data.rows)-6):
			for row in range(12,int(battle.map_data.cols)-12):
				var sea:=Vector2i(a,row)
				if not battle.nav.is_water(sea) or battle.nav.is_solid(sea,1):continue
				var point: Vector2=battle.nav.anchor_of(a,row)
				if point.distance_squared_to(center)>=best:continue
				for land in battle.nav.neighbors(sea):
					if battle.nav.is_water(land) or battle.nav.is_solid(land,0):continue
					pair=[sea,land];best=point.distance_squared_to(center);break
		assert(not pair.is_empty())
		var ship_point: Vector2=battle.nav.anchor_of(pair[0].x,pair[0].y)
		var land_point: Vector2=battle.nav.anchor_of(pair[1].x,pair[1].y)
		assert(battle.commands._spawn_unit(47,battle.player_owner,ship_point.x,ship_point.y,true))
		var ship: Dictionary=battle.units.back()
		for i in range(2):
			assert(battle.commands._spawn_unit(32,battle.player_owner,land_point.x,land_point.y,true))
			battle.selected=[battle.units.back()]
			assert(battle.commands._order_board(ship)==1);battle.commands._step_unit(battle.units.back(),battle.SIM_DT)
		assert(ship.carry_n==2)
		battle.selected=[ship];battle.visibility.update(battle.units,battle.player_owner)
		battle.cam.position=ship_point-(battle.view.battle_rect().get_center()-surface.get_visible_rect().size*0.5)/battle.cam.zoom
		battle.view.clamp_camera();battle.cam.force_update_scroll()
	if "--disband" in OS.get_cmdline_user_args(): battle.commands._order_disband()
	if "--resource-remnants" in OS.get_cmdline_user_args():
		load(get_script().resource_path.get_base_dir().path_join("economy_fixture.gd")).warehouses(battle)
		var workers: Array = battle.units.filter(func(u): return int(u.unit) == 30 and int(u.owner)==battle.player_owner)
		var crops: Array = battle.decor_targets.filter(func(t): return int(t.unit) == 102 and t.alive)
		var start := Vector2(workers[0].ax,workers[0].ay)
		crops.sort_custom(func(a,b): return start.distance_squared_to(Vector2(a.ax,a.ay)) < start.distance_squared_to(Vector2(b.ax,b.ay)))
		var crop: Dictionary = crops[0]
		battle.commands._order_gather(crop)
		for tick in range(360):
			battle.commands._update_gates()
			for worker in workers: battle.commands._step_unit(worker,battle.SIM_DT)
			battle.visibility.update(battle.units,battle.player_owner)
		assert(not crop.alive and crop.phase == 3)
		var focus := Vector2(crop.ax,crop.ay)
		battle.cam.position = focus - (battle.view.battle_rect().get_center() - surface.get_visible_rect().size*0.5) / battle.cam.zoom
		battle.view.clamp_camera(); battle.cam.force_update_scroll()
	if "--production-menu" in OS.get_cmdline_user_args():
		load(get_script().resource_path.get_base_dir().path_join("economy_fixture.gd")).warehouses(battle)
		var base: Dictionary = battle.selected[0]
		var barracks: Dictionary = battle.commands._place_building(battle.player_owner,12,Vector2(base.ax+300,base.ay+100))
		assert(not barracks.is_empty())
		battle.player_tech.level = 1
		battle.selected = [barracks]
	if "--research-menu" in OS.get_cmdline_user_args():
		var hero: Dictionary = battle.selected[0]
		assert(battle.commands._spawn_unit(14,battle.player_owner,hero.ax+100,hero.ay,true))
		battle.gold=10000;battle.wood=10000;battle.stone=10000
		battle.selected=[battle.units.back()]
		assert(battle.commands._start_tech(3))
		for tick in range(100): battle.commands._process_tech(battle.SIM_DT)
	if "--combat-flight" in OS.get_cmdline_user_args():
		var leader: Dictionary=battle.selected[0]
		var point:=Vector2(leader.ax,leader.ay)
		assert(battle.commands._spawn_unit(45,battle.player_owner,point.x-60,point.y+50,true))
		var archer: Dictionary=battle.units.back()
		assert(battle.commands._spawn_unit(34,battle.player_owner,point.x-100,point.y+90,true))
		var cat: Dictionary=battle.units.back()
		assert(battle.commands._spawn_unit(32,int(battle.commands.ai_owners()[0]),point.x+200,point.y+50,true))
		var target: Dictionary=battle.units.back()
		for attacker in [archer,cat]:
			attacker.state="attack";attacker.target=target;attacker.action_phase=2
			battle.commands._fire_attack(attacker,target)
		for tick in range(8):battle.projectiles.step()
		assert(battle.projectiles.active.size()==2)
		battle.selected=[archer];battle.visibility.update(battle.units,battle.player_owner)

	if "--harvest" in OS.get_cmdline_user_args():
		var workers: Array = battle.units.filter(func(u): return int(u.unit) == 30 and int(u.owner)==battle.player_owner)
		var resource: Dictionary = battle.commands._nearest_resource(Vector2(workers[0].ax, workers[0].ay))
		battle.commands._order_at(Vector2(resource.ax, resource.ay - 20))
		for step in range(210):
			battle.commands._update_gates()
			for worker in workers: battle.commands._step_unit(worker, 1.0 / 30.0)
			battle.visibility.update(battle.units, battle.player_owner)
		var focus := Vector2(workers[0].ax, workers[0].ay)
		battle.cam.position = focus - (battle.view.battle_rect().get_center() - surface.get_visible_rect().size * 0.5) / battle.cam.zoom
		battle.view.clamp_camera(); battle.cam.force_update_scroll()
	if "--gate-open" in OS.get_cmdline_user_args() or "--gate-closed" in OS.get_cmdline_user_args():
		var orientation := 17 if "--gate-alt" in OS.get_cmdline_user_args() else 16
		var candidates: Array = battle.units.filter(func(u): return int(u.unit) == orientation and int(u.owner) == int(battle.player_owner))
		var gate_index := 0 if orientation == 17 else 1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--gate-index="): gate_index = int(arg.substr(13))
		var gate: Dictionary = candidates[gate_index]
		var worker: Dictionary = battle.units.filter(func(u): return int(u.unit) == 30 and int(u.owner)==battle.player_owner)[0]
		worker.ax = float(gate.ax) + 22; worker.ay = float(gate.ay) - 33
		if "--gate-closed" in OS.get_cmdline_user_args(): worker.ay = float(gate.ay) - 143
		battle.view.place_unit(worker)
		battle.commands._update_gates()
		assert(bool(gate.gate_open) == ("--gate-open" in OS.get_cmdline_user_args()))
		battle.visibility.update(battle.units, battle.player_owner)
		var focus := Vector2(gate.ax, gate.ay - 33)
		battle.cam.position = focus - (battle.view.battle_rect().get_center() - surface.get_visible_rect().size * 0.5) / battle.cam.zoom
		battle.view.clamp_camera(); battle.cam.force_update_scroll()
	for u in battle.units: battle.view.update_visual(u)
	battle.view.update_panel(); battle.view.update_hud_text()
	if "--build-menu" in OS.get_cmdline_user_args(): battle.view._open_build_menu()
	if "--show-menu" in OS.get_cmdline_user_args():
		# 截图同时验证真正的顶部匾额命中路径。
		var point: Vector2 = battle.view.banner_tex.get_global_rect().get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point; event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
			surface.push_input(event, true)
		assert(battle.view.battle_menu.is_open, "点击赤壁匾额必须打开菜单")
		if "--show-settings" in OS.get_cmdline_user_args(): battle.view.battle_menu.show_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			surface.get_texture().get_image().save_png(a.substr(10))
	print("CAPTURE DONE viewport=",surface.get_visible_rect().size," zoom=",battle.cam.zoom," selection=",battle.selected.size())
	if surface != root: surface.free()
	else: battle.free()
	quit()
