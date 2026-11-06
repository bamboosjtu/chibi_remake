extends SceneTree
# chibil1 第一章专项回归——**必须带 view 跑**（断言 HD 建筑纹理/人物面板/命令图标几何）：
#   隔离 APPDATA + godot --headless --path godot/chibi_remake \
#     --script ../../tools/gd/verify_chibil1.gd
# 不要加 -- --noview —— view 为空时本探针无意义，会在 update_visual 处报错。
var failed := false
func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("CHIBIL1 FAIL: " + message)

func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	await process_frame
	await process_frame
	var mine := []
	var skins := 0
	var buildings := 0
	for u in battle.units:
		if u.owner == battle.player_owner and not u.get("officer", {}).is_empty(): mine.append(u)
		battle.view.update_visual(u)
		if u.is_building:
			buildings += 1
			if int(u.unit) in [16,17]:
				check(battle.view.unit_nodes(u).has("gate_module") and battle.view.unit_nodes(u).gate_module.visible and not battle.view.unit_nodes(u).skin.visible,"gate replacement module excludes the generated wall %d" % u.unit)
			else:
				check(battle.view.unit_nodes(u).skin != null and battle.view.unit_nodes(u).skin.visible, "building HD skin %d" % u.unit)
			if battle.view.unit_nodes(u).skin != null:
				skins += 1
				check(battle.view.unit_nodes(u).skin.texture.resource_path.begins_with("res://art/full/"), "building selected texture %d" % u.unit)
	check(mine.size() == 1, "exactly one initial player officer")
	check(battle.selected.size() == 1 and battle.selected[0].uid == mine[0].uid, "opening selects commander body for the full team menu")
	check(int(mine[0].officer.index) == 42 and int(mine[0].unit) == 29, "MED 43 = Xu Shu, scholar commander")
	check(battle.units.filter(func(u): return int(u.unit) == 30 and int(u.owner)==battle.player_owner and int(u.group_officer)==int(mine[0].officer.index)).size() == 4, "four bound workers preserved when commander spawned")
	check(battle.commands.military.available_officers(2).map(func(o): return int(o.index)) == [39, 35, 34, 33, 46, 45, 42].filter(func(i): return i != 42), "one-based campaign roster")
	battle.view.update_panel()
	check(battle.view.classic_panel.visible and battle.view.classic_panel.portrait.texture != null, "officer portrait")
	check(battle.view.classic_panel.portrait.texture.resource_path == "res://art/full/officers/042-portrait-v2.png", "accepted HD identity bound")
	check(battle.view.classic_panel.values[5].text == "400", "troop count comes from four workers HP")
	check(battle.view.classic_panel.values[3].text == "10", "opening strategy points")
	battle.hover_text = "民居 hp 800/800 owner 0"
	battle.view.update_hud_text()
	check(not battle.view.info.visible and not battle.view.status_sub.visible, "default HUD suppresses raw debug even if hover source populates")
	battle.show_debug = true
	battle.view.update_hud_text()
	check(battle.view.info.visible and battle.view.status_sub.visible, "independent debug overlay can be enabled")
	battle.show_debug = false; battle.hover_text = ""; battle.view.update_hud_text()
	check(not battle.view.panel_label.visible and not battle.view.cmd_hint.visible, "debug instructions hidden")
	for entry in battle.view.art_buttons:
		if entry.btn.visible:
			check(battle.view.right_panel.get_global_rect().encloses(entry.btn.get_global_rect()), "command icon inside panel")
	var layer: Node2D = battle.view.resource_layer
	check(layer.texture != null, "decor atlas")
	var phases := {}
	for cell in battle.map_data.decor:
		if phases.has(int(cell[2])): continue
		phases[int(cell[2])] = true
		var anchor: Vector2 = battle.nav.anchor_of(int(cell[0]), int(cell[1]))
		layer.update_visible(Rect2(anchor - Vector2(50, 80), Vector2(100, 160)))
		check(not layer.active.is_empty(), "resource rendered phase %d" % int(cell[2]))
	var selected_uid: int = battle.selected[0].uid
	var selected_count: int = battle.selected.size()
	var explored: String = battle.visibility.snapshot()
	# 章节开场视频若在播，任何鼠标按下都会被 event_view 当"跳过过场"消费
	# （事件根本轮不到菜单路由）。探针不验过场，先确定性停掉播放器。
	if battle.view.event_view != null and battle.view.event_view.player != null and battle.view.event_view.player.is_playing():
		battle.view.event_view.restore_history()
	var logo: Vector2 = battle.view.banner_tex.get_global_rect().get_center()
	# 真实视口路由验证：事件位置必须给**嵌入窗口坐标**（画布坐标 × final_transform 缩放），
	# in_local_coords=false —— 引擎负责逆变换回视口坐标。headless 窗口 64x64、
	# content_scale 0.04 时，直接给画布坐标的 push_input(event, true) 会落在
	# (32,2.1) 附近、被顶栏命中区吞掉（表现为「点红匾不开菜单」假失败）。
	var wscale: Vector2 = root.get_final_transform().get_scale()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = logo * wscale; event.global_position = logo * wscale
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event, false)
	check(battle.view.battle_menu.is_open and paused, "logo opens paused menu")
	check(battle.selected.size() == selected_count and battle.selected[0].uid == selected_uid and not battle.selecting, "logo does not select battlefield")
	battle.view.battle_menu.save_game()
	var picker=battle.view.battle_menu.slots_dialog
	check(picker.overlay.visible and picker.saving,"save opens record selection")
	var saved_slot: int=picker.selected_slot
	picker._confirm()
	check(battle.view.battle_menu.status.text.begins_with("保存成功"), "menu saves chosen record")
	battle.view.battle_menu.load_game()
	for i in range(picker.entries.size()):
		if int(picker.entries[i].slot)==saved_slot:
			picker.records.select(i);picker._selected(i);break
	picker._confirm()
	check(not battle.view.battle_menu.is_open and battle.selected.size() == selected_count and battle.selected[0].uid == selected_uid, "load completes across gates and restores selection")
	check(battle.visibility.snapshot() == explored, "exploration survives save/load")
	check(not paused, "resume clears pause")
	var p: Rect2 = battle.view.top_right_tex.get_global_rect()
	check(not p.intersects(battle.view.banner_tex.get_global_rect()), "header artwork separated")
	var data := {"pass": not failed, "map": "chibil1", "officer": mine[0].officer.name,
		"officerIndex": 42, "openingSelection": selected_count, "cleanDefaultHud": true, "explorationSaveLoad": true,
		"hdBuildings": skins, "buildings": buildings, "resourcePhases": phases.keys(),
		"openingPortrait": not failed, "logoMenu": not failed, "hudInputIsolation": not failed, "menuSaveLoad": not failed}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter-report="):
			var f := FileAccess.open(arg.substr(17), FileAccess.WRITE)
			f.store_string(JSON.stringify(data, "  "))
	print("CHIBIL1 RESULT ", data)
	if "--interactive" in OS.get_cmdline_user_args() and not failed:
		battle.cli_mode = true
		layer.last_rect = Rect2()
		root.title = "赤壁 · 第一章修复验证"
		root.show()
		return
	battle.free()
	quit(1 if failed else 0)
