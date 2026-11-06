extends Node
## 12 首 WAVE.EXP BGM：主菜单 Start，战场 Record；OGG 循环。
var _player: AudioStreamPlayer
var _path := ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -9.0
	add_child(_player)

func play(path: String) -> void:
	if _player == null or path == _path: return
	if DisplayServer.get_name() == "headless": return
	var stream = load(path) if ResourceLoader.exists(path) else preload("res://presentation/audio/generated_audio.gd").stream(path,true)
	if not stream is AudioStream: return
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
	_path = path
	_player.stream = stream
	_player.play()

func stop() -> void:
	_path = ""
	if _player != null: _player.stop()
