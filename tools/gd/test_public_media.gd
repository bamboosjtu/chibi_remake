extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map="chibil1"
	var b:Node=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false);b.cli_mode=true;b.ai=null
	var media:Node=b.view.event_view
	for entry in media.catalog.values():assert(not FileAccess.file_exists(entry.path))
	assert(not media.play_media("res://media/videos/LIU1.AVI") and not paused)
	assert(not ResourceLoader.exists("res://media/music/Start.ogg"))
	assert(b.sfx._load_wav("res://media/sfx/fallback.wav")!=null)
	print("PUBLIC MEDIA PASS original video absent / missing opening never pauses / generated audio available")
	b.free();quit()
