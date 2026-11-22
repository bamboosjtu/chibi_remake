extends SceneTree
const HD_ROOT := "res://media/videos/"
class BriefingFixture extends CanvasLayer:
	var opened := false
	func open() -> void: opened = true
var finished := false
var events: CanvasLayer

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): if not finished: quit(1))
	run.call_deferred()

func run() -> void:
	var EventView: Script = load("res://presentation/media/event_view.gd")
	var BattleUI: Script = load("res://presentation/battle/view/battle_view_state.gd")
	var Controller: Script = load("res://presentation/battle/view/controller.gd")
	var host := Node2D.new()
	root.add_child(host)
	events = EventView.new(host)
	host.add_child(events)
	var ui: RefCounted = BattleUI.new()
	ui.event_view = events
	var controller: Object = Controller.new(ui, host)
	var briefing := BriefingFixture.new()
	host.add_child(briefing)
	ui.briefing = briefing
	assert(not events.catalog.has("START.AVI") and not FileAccess.file_exists(HD_ROOT+"START.AVI"))
	if "--missing-hd" in OS.get_cmdline_user_args():
		assert(not events.play_startup_intro() and not events.active and not paused)
		controller.maybe_play_intro("CAO1.mp4")
		assert(briefing.opened and not events.active and not paused and not ui.opening_pending)
		assert(events.campaign_path("CAO1.AVI").is_empty())
		print("HD MISSING => BRIEFING, NO LEGACY FALLBACK PASS")
		controller.free()
		host.free()
		finished = true
		quit(0)
		return
	assert(events.play_startup_intro() and events.media_path == HD_ROOT + "START.mp4" and paused)
	assert(events.player.get_video_texture().get_size() == Vector2(1280, 720))
	assert(absf(events.player.get_stream_length() - float(events.catalog["START.mp4"].duration)) < 0.07)
	for name in ["START.mp4", "LIU1.mp4"]:
		assert(FileAccess.get_sha256(HD_ROOT + name) == events.catalog[name].sha256, name)
	for attempt in range(16):
		await create_timer(0.05, true).timeout
		if events.player.stream_position > 0.04: break
	assert(events.player.stream_position > 0.04, "HD startup decoder must advance")
	print("APPROVED HD STARTUP AND LIU1 BYTES PASS; startup decoded 1280x720 and clock advanced")
	events._finish_media()
	assert(not paused)
	var files := DirAccess.get_files_at("res://data")
	var mapped := {}
	for name in files:
		if not name.begins_with("chibic") and not name.begins_with("chibil"): continue
		if not name.ends_with(".json"): continue
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name))
		if not doc.has("scenario") or not doc.scenario.has("avi"): continue
		var original := str(doc.scenario.avi)
		assert(original.ends_with(".mp4") and not FileAccess.file_exists(HD_ROOT+original.get_basename()+".AVI"), name)
		mapped[original] = name
		controller.maybe_play_intro(str(doc.scenario.avi))
		var hd := HD_ROOT + original.get_basename() + ".mp4"
		assert(ui.opening_pending and events.active and paused, name)
		assert(events.media_path == hd and events.player.is_playing(), str([name, events.media_path]))
		assert(events.player.get_video_texture().get_size() == Vector2(1280,720), name)
		assert(absf(events.player.get_stream_length() - float(events.catalog[original].duration)) < 0.07, name)
		for attempt in range(16):
			await create_timer(0.05, true).timeout
			if events.player.stream_position > 0.04: break
		assert(events.player.stream_position > 0.04, name)
		if original == "CAO1.mp4":
			for size in [Vector2i(640, 480), Vector2i(1280, 720), Vector2i(1920, 1080)]:
				root.size = size
				await process_frame
				events._layout_video(hd)
				var screen:Transform2D = root.get_stretch_transform()*events.player.get_global_transform_with_canvas()
				var scale1 := minf(1.0,minf(float(size.x)/1280.0,float(size.y)/720.0))
				assert(screen.get_scale().is_equal_approx(Vector2(scale1,scale1)), str([size,screen.get_scale()]))
				assert(is_equal_approx((events.player.size*scale1).aspect(),1280.0/720.0))
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE
		skip.pressed = true
		events._input(skip)
		assert(not events.active and not paused, name)
		ui.opening_pending = false
	assert(mapped.size() == 34)
	assert(mapped["CAO14A.mp4"] == "chibic14.json" and mapped["CAO14.mp4"] == "chibic16.json")
	assert(mapped["LIU7.mp4"] == "chibil7a.json" and mapped["LIU8.mp4"] == "chibil7b.json")
	assert(events.play_media(events.campaign_path("CAO9.mp4")))
	var calls := [0]
	events.media_finished.connect(func(): calls[0] += 1, CONNECT_ONE_SHOT)
	for elapsed in range(290):
		await create_timer(0.10, true).timeout
		if not events.active: break
	assert(not events.active and not paused and calls[0] == 1, "natural finish must resume play")
	assert(events.play_media("res://media/videos/LISHI.AVI"))
	assert(events.media_path == "res://media/videos/LISHI.AVI")
	events._finish_media()
	print("HD CAMPAIGN PLAYBACK PASS maps=34; actual controller; stereo MP4; layout resize/aspect; skip/resume; natural finish; shared AVI")
	controller.free()
	host.free()
	finished = true
	await process_frame
	quit(0)

