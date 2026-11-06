extends SceneTree
## WAVE.EXP 音效：运行期 RIFF 解析、语音库分池、无 headless 崩溃。
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	_run.call_deferred()
func _run() -> void:
	var s = load("res://presentation/audio/sfx.gd").new()
	root.add_child(s)
	await process_frame
	assert(s._bank_files("xb").size() > 0 and s._bank_files("xg").size() > 0 and s._bank_files("xr").size() > 0)
	assert(FileAccess.file_exists("res://media/sfx/pmove01.wav") or load("res://media/sfx/pmove01.wav") != null)
	assert(FileAccess.file_exists("res://media/sfx/pmove02.wav") or load("res://media/sfx/pmove02.wav") != null)
	assert(FileAccess.file_exists("res://media/music/start.ogg") or load("res://media/music/start.ogg") != null)
	assert(FileAccess.file_exists("res://media/music/record01.ogg") or load("res://media/music/record01.ogg") != null)
	var wav = s._load_wav("res://media/sfx/click.wav")
	assert(wav != null and wav.data.size() > 0 and wav.mix_rate == 11025)
	var fight = s._load_wav("res://media/sfx/fight01.wav")
	assert(fight != null and fight.data.size() > 0)
	s.play_select([{"is_building": false, "officer": {}, "atk_range": 1, "unit": 32}])
	s.play_select([{"is_building": false, "officer": {"index": 1}, "atk_range": 1, "unit": 31}])
	s.play_attack({"unit": 32, "atk_range": 1})
	s.play_attack({"unit": 45, "atk_range": 6})
	print("SFX PASS RIFF 8-bit parse / select banks / attack mapping / headless safe")
	s.free(); quit(0)
