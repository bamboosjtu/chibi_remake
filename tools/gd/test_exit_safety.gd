extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920,1080)
	var mode := "victory"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--exit-case="): mode = arg.substr(12)
	var game: Node = root.get_node("Game")
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false); battle.cli_mode = true
	battle.gold = 1234
	assert(battle.session_actions.save_game())
	var old_hash := FileAccess.get_sha256(game.SAVE_PATH)
	battle.gold = 4321
	battle.game_end = 2 if mode == "defeat" else 1
	if mode == "failure": game.force_save_failure = true
	if mode == "uninitialized": battle.scene.ready_to_save = false
	battle._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if mode in ["failure","uninitialized"]:
		assert(FileAccess.get_sha256(game.SAVE_PATH) == old_hash)
		if mode == "failure": assert(battle.view.battle_menu.is_open)
	else:
		var saved: Dictionary = game.load_save()
		assert(saved.resources.gold == 4321 and saved.gameEnd == battle.game_end)
	battle.free()
	print("EXIT SAFETY PASS ",mode)
	quit()
