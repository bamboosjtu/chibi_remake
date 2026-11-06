extends SceneTree
var b: Node2D
var output := "user://duel-review"
var done := false
func _initialize() -> void:
	create_timer(80).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func capture(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	await process_frame;await process_frame
	for child in b.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			while not (child._pending.is_empty() and not child._wanted.is_empty() and child._wanted.keys().all(func(k):return child.active.has(k))):
				await create_timer(0.01,true).timeout
	var caster:Dictionary=b.selected[0]
	var enemy:Dictionary=b.units.filter(func(u):return u.owner!=b.player_owner and not u.get("officer",{}).is_empty())[0]
	enemy.ax=caster.ax+88;enemy.ay=caster.ay
	caster.officer.might=100;caster.officer.level=9;caster.officer.tier=1
	enemy.officer.might=1;enemy.officer.level=0;enemy.officer.tier=4
	caster.hp=caster.maxhp;enemy.hp=enemy.maxhp
	b.visibility.update(b.units,b.player_owner)
	b.commands._duel_begin();seed(17);b.commands._duel_at(Vector2(enemy.ax,enemy.ay-enemy.h*0.5))
	assert(paused and b.view.event_view.active)
	await create_timer(2,true).timeout
	assert(caster.hp==caster.maxhp and enemy.hp==enemy.maxhp)
	assert(not b.view.event_view.caption.text.contains("胜出"))
	var image:Image=b.view.event_view.player.get_video_texture().get_image()
	assert(image.save_png(output.path_join("duel-decoded.png"))==OK)
	var metadata:=FileAccess.open(output.path_join("duel-decoded.json"),FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"position":b.view.event_view.player.stream_position}));metadata.close()
	await capture("duel-clash")
	await create_timer(14,true).timeout
	assert(b.view.event_view.caption.text.contains("胜出"))
	assert(caster.hp==caster.maxhp and enemy.hp==enemy.maxhp)
	await capture("duel-ending")
	await b.view.event_view.media_finished
	assert(not paused and caster.hp==caster.maxhp*0.9 and enemy.hp==0)
	print("DUEL NATIVE PASS natural 28-second playback / decoded frames / delayed ending title / exact settlement")
	b.cli_mode=false;b.game_end=1;b.view.completion.automatic=true;b.commands._show_end(1)
	await capture("victory-next-chapter")
	assert(paused and b.view.completion.countdown)
	b.view.completion.stay();assert(not paused and not b.view.completion.countdown)
	done=true;b.free();quit()
