extends SceneTree
var b: Node2D
var output := "user://research-review"
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(1))
	run.call_deferred()
func capture(name: String) -> void:
	for unit in b.units:b.commands._update_visual(unit)
	b.view.update_panel();b.commands._view_hud()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.view.set_process(false)
	await process_frame;await process_frame
	# Exercise the real automatic opening, including the skip-to-briefing handoff.
	if b.view.event_view.player.is_playing():
		var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true
		root.push_input(key,false)
	assert(b.view.briefing.is_open and paused)
	for child in b.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			var deadline:=Time.get_ticks_msec()+5000
			while not child._pending.is_empty() and Time.get_ticks_msec()<deadline:await create_timer(0.01,true).timeout
	await capture("mission-opening")
	for dimensions in [Vector2i(640,480),Vector2i(1560,1440),Vector2i(1920,1080)]:
		root.size=dimensions;await process_frame;await process_frame
		var box: Rect2=b.view.briefing.panel.get_global_rect()
		assert(root.get_visible_rect().encloses(box))
		assert(box.encloses(b.view.briefing.done_button.get_global_rect()))
	var point: Vector2=b.view.briefing.done_button.get_global_rect().get_center()*root.get_final_transform().get_scale()
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new();click.position=point;click.global_position=point
		click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;root.push_input(click,false)
	assert(not b.view.briefing.is_open and not paused,"the real Complete button resumes the battle")
	var leader: Dictionary=b.selected[0]
	var workers: Array=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==30)
	var target:=Vector2(leader.ax,leader.ay)
	b.cam.position=target-(b.view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/b.cam.zoom
	b.cam.force_update_scroll()
	await capture("worker-leader-eight")
	b.selected=[workers[0]];await capture("worker-member-three")
	assert(b.commands._spawn_unit(32,b.player_owner,float(leader.ax)+120,float(leader.ay)+80,true))
	var soldier: Dictionary=b.units.back()
	b.selected=[soldier];await capture("soldier-ungrouped-four")
	var roster: Array=b.commands.available_officers(b.player_owner)
	b.commands._order_form_up(int(roster[0].index))
	var commander: Dictionary=b.selected[0]
	await capture("combat-leader-nine")
	b.selected=[soldier];await capture("soldier-member-four")
	b.selected=[commander];commander.officer.level=0;commander.officer.exp=199
	b.commands._grant_officer_exp(soldier,1)
	await capture("officer-promotion")
	print("RESEARCH VISUAL PASS automatic video skip -> briefing / three window sizes / selection panels / promotion")
	b.free();quit()
