extends SceneTree
## Screenshot-backed slot identities, level gates and world-click dismissal.
var b: Node2D
var done := false
var output := ""

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	return event

func capture(label: String) -> void:
	if output == "" or DisplayServer.get_name() == "headless": return
	b.view.update_panel()
	b.view.update_hud_text()
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.substr(9)
	if output != "": DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	root.get_node("Game").current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	b.player_commands.set_process(false)
	await process_frame; await process_frame
	var leader: Dictionary = b.selected[0]
	leader.team_kind = "combat"; leader.mou = 10000
	var view = b.view
	var skill_masks := [0,1,385,449,457,463,495,511,511,511]
	var form_counts := [3,3,3,6,6,8,10,10,10,10]
	for level in range(10):
		leader.officer.level = level
		view.art_sub = ""; view._refresh_cmd_art()
		var grid: Array = []
		for i in range(9): grid.append(view.art_buttons[i].btn.get_global_rect())
		view.art_sub = "hot"; view._refresh_cmd_art()
		assert(view.command_panel.mask == skill_masks[level])
		for i in range(9):
			var button: TextureRect = view.art_buttons[9+i].btn
			assert(button.visible == ((skill_masks[level] & (1 << i)) != 0))
			assert(button.get_global_rect() == grid[i], "skills retain main-command size and fixed slots")
			b.commands._reset_jimou(); b.commands._jimou_begin(i)
			assert(b.jimou_pending == (i if button.visible else -1), "execution and UI share the same unlock rule")
		b.commands._reset_jimou()
		assert(not view.art_back.visible)
		view.art_sub = "form"; view._refresh_cmd_art()
		for i in range(10):
			assert(view.art_buttons[18+i].btn.visible == (i < mini(8, form_counts[level])))
		assert(view.art_buttons[29].btn.visible == (form_counts[level] == 10))
		if form_counts[level] == 10:
			assert(view._handle_cmd_key(key(KEY_C)))
			assert(view.art_sub == "form_more" and view.command_panel.mask == 259)
			for i in [8,9]: assert(view.art_buttons[18+i].btn.get_global_rect() == grid[i-8])
			assert(view.art_buttons[30].btn.visible and view._handle_cmd_key(key(KEY_C)))
			assert(view.art_sub == "form")
		else:
			var before: int = b.commands._state_digest()
			b.commands._set_formation(9)
			assert(b.commands._state_digest() == before, "locked formations cannot be forced through execution")
	leader.officer.level = 2
	view.art_sub = "hot"; view._refresh_cmd_art()
	assert(not view._handle_cmd_key(key(KEY_W)))
	assert(view._handle_cmd_key(key(KEY_X)) and b.jimou_pending == 7, "X remains recovery in bottom-centre slot")
	b.commands._reset_jimou(); view.art_sub = "hot"; view._refresh_cmd_art()
	await capture("level2-skills")
	for menu in ["hot", "form"]:
		view.art_sub = menu; view._refresh_cmd_art()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = view.battle_rect().get_center(); event.pressed = true
		root.push_input(event, true); await process_frame
		event.pressed = false; root.push_input(event, true); await process_frame
		assert(view.art_sub == "" and b.selected == [leader] and b.player_commands.batches.is_empty())
	view.art_sub = "form"; view._refresh_cmd_art(); await capture("level2-formations")
	leader.officer.level = 6
	view.art_sub = "form"; view._refresh_cmd_art(); await capture("level6-formations-first")
	view._handle_cmd_key(key(KEY_C)); await capture("level6-formations-second")
	print("ABILITY MENUS PASS ten levels / fixed skill slots / matching sizes / formation pages / locked execution / X recovery / world-click dismissal")
	done = true; quit()
