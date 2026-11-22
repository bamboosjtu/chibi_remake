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
	# Preserve the exact bank order and random draw sequence, including empty banks.
	var oracle := RandomNumberGenerator.new(); oracle.seed = 0x5A17
	for prefix in ["fight", "arrow", "throw", "missing-bank"]:
		var expected: Array = []
		for key in s._entries:
			if str(key).begins_with(prefix) and str(key).ends_with(".wav"): expected.append(str(key))
		expected.sort()
		var cached: Array = s._bank_files(prefix)
		assert(cached == expected and cached.is_read_only())
		assert(is_same(cached, s._bank_files(prefix)), "bank was rebuilt")
		if not expected.is_empty():
			for i in range(100): assert(cached[s._rng.randi() % cached.size()] == expected[oracle.randi() % expected.size()])
	s._load_index()
	assert(s._banks.is_empty(), "index reload must invalidate bank cache")
	assert(FileAccess.file_exists("res://media/sfx/pmove01.wav") or load("res://media/sfx/pmove01.wav") != null)
	assert(FileAccess.file_exists("res://media/sfx/pmove02.wav") or load("res://media/sfx/pmove02.wav") != null)
	assert(FileAccess.file_exists("res://media/music/start.ogg") or load("res://media/music/start.ogg") != null)
	assert(FileAccess.file_exists("res://media/music/record01.ogg") or load("res://media/music/record01.ogg") != null)
	var wav = s._load_wav("res://media/sfx/click.wav")
	assert(wav != null and wav.data.size() > 0 and wav.mix_rate == 11025)
	var fight = s._load_wav("res://media/sfx/fight01.wav")
	assert(fight != null and fight.data.size() > 0)
	s.play_select(false)
	s.play_select(true)
	s.play_attack(32, 1)
	s.play_attack(45, 6)
	print("SFX PASS RIFF 8-bit parse / select banks / attack mapping / headless safe")
	s.free(); quit(0)
