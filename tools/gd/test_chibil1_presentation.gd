extends SceneTree
var _done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not _done: quit(1))
	_run.call_deferred()

func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	for dimensions in [Vector2i(640, 480), Vector2i(1920, 1080), Vector2i(1560, 1440)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var battle: Node2D = load("res://main.tscn").instantiate()
		viewport.add_child(battle)
		battle.set_process(false); battle.cli_mode = true
		await process_frame; await process_frame
		var view: Node2D = battle.view
		var expected := minf(float(dimensions.x) / 640.0, float(dimensions.y) / 480.0)
		assert(is_equal_approx(battle.cam.zoom.x, expected))
		var area: Rect2 = view.battle_rect()
		var building: Dictionary = {}
		for u in battle.units:
			if int(u.unit) == 0 and int(u.owner) == battle.player_owner: building = u
		assert(not building.is_empty())
		var centre: Vector2 = view.get_canvas_transform() * Vector2(building.ax, building.ay - 60)
		var composition := (centre.x - area.position.x) / area.size.x
		assert(composition > 0.65 and composition < 0.95, "HQ must stay toward the right")
		assert(battle.selected.size() == 1)
		var leader: Dictionary = battle.selected[0]
		var panel: Rect2 = view.right_panel.get_global_rect()
		var info: Rect2 = view.classic_panel.get_global_rect()
		for spec in [["", 0, 8], ["hot", 0, 0], ["hot", 2, 3], ["hot", 9, 9], ["form", 2, 3], ["form", 9, 9], ["form_more", 9, 3]]:
			var menu: String = str(spec[0])
			leader.officer.level = int(spec[1])
			view.art_sub = menu
			view._refresh_cmd_art()
			var visible: Array = view.art_buttons.filter(func(entry): return entry.btn.visible and str(entry.sub) != "back")
			assert(visible.size() == int(spec[2]), "menu=%s level=%d visible=%d expected=%d" % [menu, int(spec[1]), visible.size(), int(spec[2])])
			var columns := {}
			for entry in visible:
				var rect: Rect2 = entry.btn.get_global_rect()
				assert(panel.encloses(rect), "menu icon outside the right panel")
				assert(not info.intersects(rect), "menu icon must stay below the officer panel")
				columns[str(roundf(rect.position.x))] = true
			assert(columns.size() == (0 if int(spec[2]) == 0 else 3), "menu=%s columns=%d" % [menu, columns.size()])
			assert(not view.art_back.visible)
		view._close_art_sub()
		var hero: Dictionary = battle.selected[0]
		assert(battle.view.unit_nodes(hero).spr.texture == null, "covered source atlas must not be uploaded")
		view.set_frame(hero, 29) # 原辅助轮廓也使用独立高清切片。
		assert(battle.view.unit_nodes(hero).spr.texture == null and battle.view.unit_nodes(hero).skin.visible)
		assert(battle.view.unit_nodes(hero).skin.texture.resource_path.ends_with("/units/029/utility-v1.png"), "独立补绘切片不能被父页纹理覆盖")
		view.set_frame(hero, 0)
		assert(battle.view.unit_nodes(hero).skin.visible and battle.view.unit_nodes(hero).spr.self_modulate.a < 0.1)
		var colour: ShaderMaterial = battle.view.unit_nodes(hero).skin.material
		assert(colour != null and int(battle.view.unit_nodes(hero).skin.get_meta("owner")) == 0, "human army uses original magenta palette slot")
		var ramp: GradientTexture1D = colour.get_shader_parameter("team_ramp")
		var tint := ramp.gradient.sample(0.6)
		assert(tint.r > tint.g and tint.b > tint.g, "magenta team ramp")
		battle.commands._select_click(Vector2(hero.ax, hero.ay - hero.h * 0.5), false)
		assert(battle.selected.size() == 1 and int(battle.selected[0].officer.index) == 42)
		var fog: RefCounted = battle.visibility
		var position := Vector2(hero.ax, hero.ay)
		assert(fog.is_visible(position) and not fog.is_visible(Vector2(3500, 100)))
		var explored: String = fog.snapshot()
		assert(not fog.valid_snapshot("bad-base64") and not fog.valid_snapshot(3))
		var snapshot: Dictionary = battle.commands._save_extra()
		assert(root.get_node("Game").save_game(battle.units, battle.commands._resources(), snapshot))
		var corrupt: Dictionary = root.get_node("Game").load_save()
		corrupt.simulation.explored = "wrong-size"
		var digest: int = battle.commands._state_digest()
		assert(not battle.saver.apply_snapshot(corrupt))
		assert(digest == battle.commands._state_digest() and fog.snapshot() == explored)
		battle.commands._unassign_officer(hero)
		for member in battle.units:
			if member.owner == battle.player_owner: assert(int(member.get("group_officer", -1)) != 42, "released commander must not retain followers")
		print("PRESENTATION PASS ", dimensions, " zoom=", expected, " HQ fraction=", composition, " skills / palette / group / fog / rejected-load unchanged")
		viewport.free()
	var state = load("res://simulation/systems/battle_visibility.gd").new()
	state.setup(Vector2(4048, 3130))
	var scout := {"ax": 500.0, "ay": 500.0, "unit": 30, "owner": 2, "alive": true, "is_building": false, "vision": 4}
	state.update([scout], 2)
	var previous: String = state.snapshot()
	scout.ax = 2000.0
	state.update([scout], 2)
	assert(not state.is_visible(Vector2(500, 500)) and state.is_visible(Vector2(2000, 500)))
	assert(state.snapshot() != previous and state.explored[floori(500 / 11.0) * state.width + floori(500 / 22.0)] == 1)
	var after_move: String = state.snapshot()
	state.restore(after_move, [scout], 2)
	assert(state.snapshot() == after_move)
	print("PRESENTATION PASS exploration: movement reveals new ground, old ground remembered, deterministic restore")
	_done = true; quit()
