extends SceneTree
var b:Node2D
var done:=false
var callbacks:=0
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	var media=b.view.event_view
	assert(media.catalog.size()==47 and ClassDB.class_exists("VideoStreamFFmpeg"))
	for name in media.catalog:
		var row:Dictionary=media.catalog[name]
		assert(FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path)==row.sha256)
	print("ORIGINAL MEDIA BYTES PASS 47 supplied AVI files / exact SHA256 / no conversion products")
	for name in media.catalog:
		var row:Dictionary=media.catalog[name]
		assert(media.play_media(row.path) and paused and media.player.is_playing(),name)
		assert(media.player.stream.file==row.path and media.player.stream.resource_path==row.path)
		assert(media.player.get_video_texture().get_size()==Vector2(row.width,row.height))
		await create_timer(0.10,true).timeout
		media._finish_media();assert(not paused)
	# The game's canvas stretch must never enlarge or shrink a video pixel.
	assert(media.play_media("res://media/videos/LIU1.AVI"))
	for size in [Vector2i(640,480),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;await process_frame;await process_frame
		media._layout_video(media.media_path)
		var screen:Transform2D=root.get_stretch_transform()*media.player.get_global_transform_with_canvas()
		assert(screen.get_scale().is_equal_approx(Vector2.ONE),"video pixels must remain 1:1 at every window size")
		assert(media.player.size==Vector2(320,240) and not media.player.expand)
		var origin:Vector2=screen*Vector2.ZERO
		assert(origin.is_equal_approx((Vector2(size)-Vector2(320,240))*0.5),"native image centered on black")
	media._finish_media()
	print("ORIGINAL MEDIA PLAYBACK PASS 47 Indeo3 AVI / native dimensions / 640-1280-1920 window pixel scale1 / centered / no stretch")
	assert(media.play_media("res://media/videos/LDAN.AVI",func():callbacks+=1,"test","result",14.0,[[24.0,38.0],[78.0,87.0]]))
	media.player.stream_position=38.0;media._process(0)
	assert(media.segment_index==1 and is_equal_approx(media.player.stream_position,78.0) and media.caption.text=="result")
	media.player.stream_position=87.0;media._process(0)
	assert(callbacks==1 and not paused and not media.active)
	media._finish_media();assert(callbacks==1)
	assert(media.play_media("res://media/videos/EVENT6.AVI",func():callbacks+=1))
	var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
	media._input(skip);assert(callbacks==2 and not paused and not media.active)
	assert(media.play_media("res://media/videos/LIU1.AVI",func():callbacks+=1))
	media.restore_history();assert(callbacks==2 and not paused and media.player.stream==null)
	# Natural end, rather than a manually emitted finished signal, releases pause.
	assert(media.play_media("res://media/videos/LIU1.AVI",func():callbacks+=1))
	media.player.stream_position=media.player.get_stream_length()-0.15
	for step in range(40):
		await create_timer(0.05,true).timeout
		if not media.active:break
	assert(not media.active and callbacks==3 and not paused,"actual decoder end resumes game once")
	paused=true
	assert(media.play_media("res://media/videos/LISHI.AVI"));media._finish_media();assert(paused)
	paused=false
	assert(not media.play_media("res://media/videos/absent.AVI") and not paused)
	print("ORIGINAL MEDIA LIFECYCLE PASS original LDAN result spans / natural finish / skip / one callback / load cancels / prior pause / missing file")
	b.free();done=true;await process_frame;quit()
