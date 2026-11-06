extends Node
## 原版 WAVE.EXP 音效播放。媒体导出为 8-bit/11025Hz 单声道 WAV；
## 运行期直接解析 RIFF，避免依赖每个 wav 的 .import 缓存（发布 PCK 内同样可用）。

const INDEX_PATH := "res://data/db/audio_index.json"
const MAX_PLAYERS := 8

var _players: Array = []
var _next := 0
var _entries := {}          # 小写文件名 -> 路径
var _cache := {}            # 路径 -> AudioStreamWAV
var _initialized := false
var _ids := {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 0x5A17

func _ready() -> void:
	_load_index()
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_initialized = true

func _load_index() -> void:
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f == null: return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary: return
	for e in data.get("entries", []):
		if not e is Dictionary: continue
		var path := str(e.get("file", ""))
		if path == "": continue
		_entries[path.get_file().to_lower()] = path
		if str(e.get("kind",""))=="sfx":_ids[int(e.id)]=path.get_file()

func play_id(id: int) -> void:
	if _ids.has(id):play(str(_ids[id]))

func play(file_name: String, volume_db := -4.0, pitch := 1.0) -> void:
	if not _initialized or _players.is_empty(): return
	if DisplayServer.get_name() == "headless": return
	var key := file_name.to_lower()
	var path := str(_entries.get(key, ""))
	if path == "": return
	var stream: AudioStreamWAV = _cache.get(path, null)
	if stream == null:
		stream = _load_wav(path)
		if stream == null: return
		_cache[path] = stream
	var p: AudioStreamPlayer = _players[_next % _players.size()]
	_next += 1
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func _load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return preload("res://presentation/audio/generated_audio.gd").stream(path)
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		# 导出包可能把 WAV 转成导入后的 .sample；优先用导入资源兜底。
		var imported = load(path)
		return imported as AudioStreamWAV
	var pos := 12
	var channels := 1
	var rate := 11025
	var bits := 8
	var pcm := PackedByteArray()
	while pos + 8 <= bytes.size():
		var tag := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if tag == "fmt " and body + 16 <= bytes.size():
			channels = bytes.decode_u16(body + 2)
			rate = int(bytes.decode_u32(body + 4))
			bits = bytes.decode_u16(body + 14)
		elif tag == "data":
			pcm = bytes.slice(body, mini(bytes.size(), body + size))
		pos = body + size + (size & 1)
	if pcm.is_empty(): return null
	var stream := AudioStreamWAV.new()
	stream.mix_rate = rate
	stream.stereo = channels >= 2
	stream.format = AudioStreamWAV.FORMAT_8_BITS if bits == 8 else AudioStreamWAV.FORMAT_16_BITS
	if bits == 8:
		# WAV 8-bit 是 unsigned，Godot 的 FORMAT_8_BITS 需要 signed。
		for i in range(pcm.size()):
			pcm[i] = (int(pcm[i]) - 128) & 0xFF
	stream.data = pcm
	return stream

## 选中：武将优先 XR（选人/武将语音）；弓兵 XG；其余步兵/骑兵 XB。
func play_select(units: Array) -> void:
	if units.is_empty(): return
	var hero := false
	var mobile := false
	for u in units:
		if bool(u.get("is_building", false)): continue
		mobile = true
		if not (u.get("officer", {}) as Dictionary).is_empty(): hero = true
	if not mobile: return
	# WAVE 里的两条人声应答：pmove01=“主公有何吩咐”（武将），pmove02=“将军请下令”（部队）。
	# XB/XG/XR 是战斗/提示音，不是选中语音。
	play("pmove01.wav" if hero else "pmove02.wav", -5.0)

## 攻击：近战 fight、远程 arrow、投石 throw；只在实际击发时调用。
func play_attack(unit: Dictionary) -> void:
	var id := int(unit.get("unit", -1))
	var names: Array = []
	if id == 34: names = _bank_files("throw")
	elif int(unit.get("atk_range", 1)) > 1 or id in [45, 46, 47, 48, 49, 52]: names = _bank_files("arrow")
	else: names = _bank_files("fight")
	if names.is_empty(): return
	play(names[_rng.randi() % names.size()], -7.0)

func _bank_files(prefix: String) -> Array:
	var out: Array = []
	for key in _entries:
		if str(key).begins_with(prefix) and str(key).ends_with(".wav"):
			out.append(str(key))
	out.sort()
	return out
