extends RefCounted
## Runs in the shipped EXE. Checks are explicit because release removes assert.
func run(battle: Node2D, phase: String) -> void:
	var tree: SceneTree = battle.get_tree()
	var game: Node = battle.get_node("/root/Game")
	if phase == "diagnose":
		var roots: Array = preload("res://app/user_storage.gd").directories()
		roots.append(OS.get_executable_path().get_base_dir())
		for directory in roots:
			var created := DirAccess.make_dir_recursive_absolute(directory)
			var path: String = directory.path_join("native-write-probe-%d.tmp" % OS.get_process_id())
			var file := FileAccess.open(path, FileAccess.WRITE)
			var error := FileAccess.get_open_error()
			if file != null:
				file.store_string("probe"); file.close(); DirAccess.remove_absolute(path)
			print("NATIVE STORAGE DIAG ", JSON.stringify({"directory":directory,"mkdir":created,"open":error}))
		tree.quit()
		return
	battle.set_process(false)
	battle.view.event_view.restore_history()
	var menu = battle.view.battle_menu
	menu.open()
	if phase == "write":
		battle.gold = 1234
		menu.buttons[1].pressed.emit()
		menu.slots_dialog.confirmed.emit(20, "native save acceptance")
		var record: Dictionary = game.load_save(20)
		if record.is_empty() or float(record.resources.gold) != 1234:
			print("NATIVE SAVE FAIL ", JSON.stringify(game.last_save_error)); tree.quit(1); return
		menu.slots_dialog.dismiss()
		menu.panel.show()
		menu.buttons[5].pressed.emit() # End battle persists the automatic slot.
		if game.load_save(0).is_empty():
			print("NATIVE AUTO SAVE FAIL ", JSON.stringify(game.last_save_error)); tree.quit(1); return
	else:
		menu.buttons[0].pressed.emit()
		menu.slots_dialog.confirmed.emit(20, "")
		if float(battle.gold) != 1234 or menu.is_open:
			print("NATIVE LOAD FAIL"); tree.quit(1); return
	print("NATIVE SAVE ACCEPTANCE PASS ", phase, " ", game.SAVE_PATH)
	tree.quit()
