extends SceneTree
## Native rendering check; run without --headless and with an isolated profile.
const Console = preload("res://presentation/hud/cheat_console.gd")
var b: Node2D
var output := "user://abilities-review"

func _initialize() -> void:
	run.call_deferred()

func key(code: int, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.unicode=unicode; event.pressed=true
	root.push_input(event)
	event=event.duplicate(); event.pressed=false
	root.push_input(event)

func capture(name: String) -> void:
	await process_frame
	b.view._refresh_metrics()
	b.view.update_hud_text()
	b.view.update_panel()
	await process_frame
	if b.cheat_input_open:
		var console: CanvasLayer = b.get_children().filter(func(child):return child.get_script()==Console)[0]
		var rect: Rect2 = b.view.battle_rect()
		assert(console.panel.position.x>=rect.position.x and console.panel.position.y>=rect.position.y,"Input bar must stay inside the resized battlefield")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,720)
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode=true; b.ai=null
	await process_frame
	await process_frame
	if FileAccess.file_exists("user://chibi_shot.png"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://chibi_shot.png"))
	assert(not b.cheats_enabled)
	key(KEY_F11)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(FileAccess.file_exists("user://chibi_shot.png"),"F11 must work without enabling cheats")
	key(KEY_ENTER)
	for character in "eternal": key(character.to_upper().unicode_at(0),character.unicode_at(0))
	assert(b.cheats_enabled and b.cheat_input_open)
	await capture("console-1280x720")
	root.size=Vector2i(1920,1080)
	await process_frame
	await capture("console-1920x1080")
	key(KEY_ENTER)
	key(KEY_F11)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(FileAccess.file_exists("user://chibi_shot.png"),"F11 must invoke the screenshot path")
	var leader: Dictionary=b.selected[0]
	leader.officer.level=9; leader.mou=1000; leader.team_kind="combat"
	b.view._act_hot_menu()
	assert(b.view.art_sub=="hot")
	await capture("magics-panel")
	assert(b.view.art_sub=="hot")
	b.view._close_art_sub()
	b.view._act_form_menu()
	assert(b.view.art_sub=="form")
	await capture("formation-panel")
	assert(b.view.art_sub=="form")
	var state_ref: WeakRef = weakref(b.state)
	b.free()
	assert(state_ref.get_ref()==null,"Opened console must not retain a closed battle")
	print("ABILITIES NATIVE PASS console /1280-1920 resize / F11 screenshot / magic-formation panels / console lifecycle")
	quit()
