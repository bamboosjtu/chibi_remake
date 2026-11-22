extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	assert(not DirAccess.dir_exists_absolute("res://media/music") and not DirAccess.dir_exists_absolute("res://media/sfx"))
	var capture:=AudioEffectCapture.new();capture.buffer_length=1.0;AudioServer.add_bus_effect(0,capture)
	var bgm:Node=load("res://presentation/audio/bgm.gd").new();root.add_child(bgm)
	bgm.play("res://media/music/Start.ogg")
	var sfx:Node=load("res://presentation/audio/sfx.gd").new();root.add_child(sfx)
	sfx.play(str(sfx._entries.keys()[0]))
	assert(bgm._player.playing and sfx._players[0].playing)
	await create_timer(0.5).timeout
	var frames:PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var peak:float=0.0
	for sample in frames:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	assert(frames.size()>1000 and peak>0.001 and peak<1.0)
	print("PUBLIC AUDIO PCK PASS no original tracks / BGM and SFX playing / mixer frames=",frames.size()," peak=",peak)
	bgm.stop();bgm.free();sfx.free();AudioServer.remove_bus_effect(0,0);quit()
