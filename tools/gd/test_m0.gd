extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func choose(dialog, slot: int) -> void:
	for i in range(dialog.entries.size()):
		if int(dialog.entries[i].slot)==slot:
			dialog.records.select(i);dialog.records.ensure_current_is_visible();dialog._selected(i);return
	assert(false,"requested record must appear in the picker")
func run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var b = load("res://main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	b.set_process(false)
	b.cli_mode = true
	await process_frame
	var game = root.get_node("Game")
	# 旧版可能留下损坏主档且没有备份；这不能永久阻止新保存。
	var orphan: String = game.SAVE_PATH.get_base_dir().path_join("damaged-without-backup.json")
	assert(DirAccess.make_dir_recursive_absolute(orphan.get_base_dir()) == OK)
	var file := FileAccess.open(orphan, FileAccess.WRITE)
	file.store_string("broken old save")
	file.close()
	var recovered: bool = game.Store.commit(orphan, '{"recovered":true}')
	assert(recovered and bool(game.Store.read(orphan).get("recovered", false)))
	# 语法完整但校验和损坏的主档，不能取代有效备份。
	var checked: String = game.SAVE_PATH.get_base_dir().path_join("checksum-backup.json")
	var payload := {"generation": 1}
	payload.checksum = game.save_checksum(payload)
	assert(game._atomic_write(checked, JSON.stringify(payload)))
	assert(game._atomic_write(checked, JSON.stringify(payload)))
	file = FileAccess.open(checked, FileAccess.WRITE)
	file.store_string('{"generation":2,"checksum":"invalid"}'); file.close()
	assert(game._atomic_write(checked, JSON.stringify(payload)))
	var backup: Dictionary = game.Store.read(checked + ".bak", game.verify_save_checksum)
	assert(backup.get("generation") == 1 and backup.get("checksum") == payload.checksum)
	b.view.event_view.restore_history()
	assert(b.view._command_icon(34).region == Rect2(1294,825,190,229), "HD command atlas uses measured separators")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(1920, 1080), Vector2i(1560, 1440), Vector2i(640, 480)]:
		root.size = dimensions
		await process_frame
		b.view.update_panel()
		var rect: Rect2 = b.view.battle_rect()
		for i in range(8):
			var button: Control = b.view.art_buttons[i].btn
			assert(button.get_global_rect().end.y <= rect.end.y, "commands must clear the bottom frame")
			assert(button.position.y >= b.view.classic_panel.position.y + b.view.classic_panel.size.y, "commands must clear the officer statistics")
			if i % 3 > 0:
				assert(is_equal_approx(button.position.y, b.view.art_buttons[i - 1].btn.position.y))
	print("M0 LAYOUT PASS: 1920x1080, 1560x1440, 640x480")
	var ok: bool = game.save_game(b.units, b.commands._resources(), b.commands._save_extra())
	print("M0 SAVE view=",b.view != null," result=",ok," error=",game.Store.last_error)
	if not ok: quit(1); return
	assert(b.saver.apply_snapshot(game.load_save()))
	print("M0 READ PASS")
	var menu = b.view.battle_menu
	menu.open()
	menu.save_game()
	assert(menu.slots_dialog.overlay.visible and paused)
	assert(menu.slots_dialog.records.item_count==20)
	choose(menu.slots_dialog,1)
	b.gold=1234;menu.slots_dialog.name_field.text="第一条进度"
	menu.slots_dialog._confirm()
	assert(menu.status.text.begins_with("保存成功") and paused)
	var automatic: Dictionary=game.load_save()
	assert(game.load_save(1).resources.gold==1234 and game.load_save(1).saveName=="第一条进度")
	b.gold=2345;menu.save_game();choose(menu.slots_dialog,2)
	menu.slots_dialog.name_field.text="第二条进度";menu.slots_dialog._confirm()
	var second: Dictionary=game.load_save(2)
	assert(second.resources.gold==2345 and game.load_save(1).resources.gold==1234 and game.load_save()==automatic)
	b.gold=3456;menu.save_game();choose(menu.slots_dialog,1)
	assert(menu.slots_dialog.confirm_button.text=="覆盖选中记录")
	menu.slots_dialog._confirm()
	assert(game.load_save(1).resources.gold==3456 and game.load_save(2)==second and game.load_save()==automatic)
	game.force_save_failure=true;menu.save_game();choose(menu.slots_dialog,2)
	menu.slots_dialog._confirm()
	assert(menu.slots_dialog.overlay.visible and menu.slots_dialog.status.text.contains("保存失败") and game.load_save(2)==second)
	game.force_save_failure=false;menu.slots_dialog.close()
	menu.load_game();choose(menu.slots_dialog,2);menu.slots_dialog._confirm()
	assert(b.gold==2345 and not paused and not menu.is_open and game.load_save(1).resources.gold==3456)
	print("SAVE SLOTS PASS two independent records / selected overwrite / unchanged automatic save / failure preserves record / selected restore")
	menu.open()
	# 用显式测试钩子让真实写盘失败，避免依赖临时文件名（保存器已改为唯一临时名）。
	var previous: Dictionary = game.load_save()
	game.force_save_failure = true
	menu.show_settings()
	b._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert(menu.is_open and menu.panel.visible and not menu.settings_panel.visible and menu.leave_button.visible and paused and menu.status.text.contains("未退出"))
	await process_frame # 若窗口关闭路径错误地 quit，下面的 PASS 不会执行。
	menu.return_to_menu()
	assert(menu.is_open and menu.leave_button.visible and paused)
	assert(game.load_save() == previous, "failed save must preserve the previous snapshot")
	print("M0 RECOVERY PASS backup=valid close=blocked")
	game.force_save_failure = false
	menu.close()
	game.startup_map_consumed = true
	menu._leave()
	await process_frame
	await process_frame
	assert(current_scene is Control and not paused, "return must stay in main menu")
	var main_menu: Control=current_scene
	game.current_map="chibic1"
	var other: Node2D=load("res://main.tscn").instantiate();root.add_child(other)
	other.set_process(false);other.cli_mode=true;other.gold=5678
	assert(other.commands._save_game(20,"另一战役"));other.free()
	game.current_map="chibil1"
	main_menu._on_load();choose(main_menu.slots_dialog,20);main_menu.slots_dialog._confirm()
	await process_frame;await process_frame
	assert(current_scene is Node2D and current_scene.map_id=="chibic1" and current_scene.gold==5678)
	var loaded_menu=current_scene.view.battle_menu
	loaded_menu.open();loaded_menu.load_game();choose(loaded_menu.slots_dialog,2);loaded_menu.slots_dialog._confirm()
	await process_frame;await process_frame
	assert(current_scene.map_id=="chibil1" and current_scene.gold==2345 and not paused)
	print("SAVE SLOTS CROSS MAP PASS main menu / last record reachable / battle menu / correct campaign and resources")
	print("M0 MENU PASS: save, failure preservation, explicit leave, main menu")
	done = true
	quit()
