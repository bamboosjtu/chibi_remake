extends Node
## Current-format save codec and application lifecycle.
const Repository = preload("res://app/saves/save_repository.gd")
const Catalog = preload("res://app/saves/slot_catalog.gd")
const CampaignSession = preload("res://app/campaign_session.gd")
var campaign := CampaignSession.new()
var repository := Repository.new(is_valid_save, can_rotate_save)
var slot_catalog := Catalog.new(repository.read_slot, save_slot_path, SAVE_SLOTS)
var startup_valid := false
var pauses: Node
var _rule_errors: Array = []

var current_map: String:
	get: return campaign.current_map
	set(value): campaign.current_map = value

var pending_load: bool:
	get: return campaign.pending_load
	set(value): campaign.pending_load = value

var pending_load_slot: int:
	get: return campaign.pending_load_slot
	set(value): campaign.pending_load_slot = value

var startup_map_consumed: bool:
	get: return campaign.startup_map_consumed
	set(value): campaign.startup_map_consumed = value

var startup_load_consumed: bool:
	get: return campaign.startup_load_consumed
	set(value): campaign.startup_load_consumed = value

var startup_video_seen: bool:
	get: return campaign.startup_video_seen
	set(value): campaign.startup_video_seen = value

var last_load_error: String:
	get: return campaign.last_load_error
	set(value): campaign.last_load_error = value

var force_save_failure: bool:
	get: return repository.force_failure
	set(value): repository.force_failure=value
var last_save_error: Dictionary:
	get: return repository.last_error
	set(value): repository.last_error=value
var storage: RefCounted:
	get: return repository.storage
	set(value): repository.storage=value
var SAVE_PATH: String:
	get: return repository.path
	set(value):
		repository.path=value
		if slot_catalog != null: slot_catalog.invalidate()
const SAVE_VERSION = preload("res://app/saves/save_format.gd").VERSION
const SAVE_SLOTS = Repository.SAVE_SLOTS
const Store = preload("res://app/json_store.gd")
const UnitSchema = preload("res://simulation/definitions/unit_schema.gd")
const Relations = preload("res://app/saves/unit_relations.gd")
const Envelope = preload("res://app/saves/save_envelope.gd")

var acceptance_enabled := false

func _init() -> void:
	acceptance_enabled = OS.is_debug_build()
	if OS.get_environment("CHIBI_ACCEPTANCE") == "1":
		var pack := OS.get_executable_path().get_base_dir().path_join("ChibiAcceptance.testpack")
		if FileAccess.file_exists(pack):
			acceptance_enabled = ProjectSettings.load_resource_pack(pack, false) or acceptance_enabled
	repository.changed.connect(slot_catalog.invalidate)
	# Godot constructs the main scene before autoload _ready callbacks.
	_rule_errors = preload("res://app/rules/rule_loader.gd").initialize()
	if _rule_errors.is_empty(): _rule_errors = preload("res://app/rules/native_backend.gd").initialize()
	if _rule_errors.is_empty(): _rule_errors = campaign.catalog.initialize()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--check-player-export" in args:
		var isolated := not acceptance_enabled and not DirAccess.dir_exists_absolute("res://testing")
		if isolated: print("PLAYER EXPORT PASS acceptance scripts absent")
		get_tree().quit(0 if isolated else 1)
		return
	if not acceptance_enabled and _has_acceptance_args(args):
		push_error("Automation requires the acceptance companion")
		get_tree().quit(1)
		return
	pauses = preload("res://app/pause_stack.gd").new(); add_child(pauses)
	var acceptance := preload("res://app/acceptance_storage.gd").configure(storage, args)
	if not acceptance.valid:
		push_error(acceptance.error); get_tree().quit(1); return
	if not _rule_errors.is_empty():
		push_error("Rule startup failed:\n" + "\n".join(_rule_errors)); get_tree().quit(1); return
	SAVE_PATH = acceptance.path
	var acceptance_run: bool = acceptance.testing
	startup_valid = true
	print("SAVE LOCATION ",SAVE_PATH)
	# 干净环境/CI 的自托管 APPDATA 下 user:// 目录可能还不存在；先建目录再写 boot/save。
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir() if acceptance_run else OS.get_user_data_dir())
	_install_cjk_font()
	if DisplayServer.get_name() != "headless": add_child(preload("res://presentation/hud/software_cursor.gd").new())
	var f := FileAccess.open(SAVE_PATH.get_base_dir().path_join("boot.log") if acceptance_run else "user://boot.log", FileAccess.WRITE)
	if f != null:
		f.store_string("boot %s\nargs=%s\n" % [Time.get_datetime_string_from_system(), str(OS.get_cmdline_user_args())])
		f.close()

func _has_acceptance_args(args: PackedStringArray) -> bool:
	for arg in args:
		if arg in ["--full-battle-bench","--selftest","--screenshot","--demo","--smoketest","--diag-nav","--levels","--keytest","--mousetest"]:
			return true
		for prefix in ["--bench-","--shot=","--simtest=","--selftest-fault=","--save-test-","--native-save=","--hud-click","--hud-select","--hud-hot"]:
			if arg.begins_with(prefix): return true
	return false

func diagnostic_path(path: String) -> String:
	if OS.is_debug_build(): return path
	var directory := OS.get_environment("CHIBI_ACCEPTANCE_OUTPUT").replace("\\","/").simplify_path()
	var target := path.replace("\\","/").simplify_path()
	if acceptance_enabled and directory.is_absolute_path() and target.begins_with(directory.trim_suffix("/") + "/"):
		return target
	return ""

## 内置中文字体：运行时直接加载 OTF，不依赖编辑器导入缓存（新克隆/无 .godot 也能跑）。
## 导出包通过 include_filter="*.otf" 带上原始字体；失败时退回系统字体并留警告。
func _install_cjk_font() -> void:
	var path := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
	# 正式包只带导入后的 .fontdata；开发目录没有 .godot 缓存时回退到直接读 OTF。
	if ResourceLoader.exists(path):
		var imported = load(path)
		if imported is FontFile:
			ThemeDB.fallback_font = imported
			return
	var font := FontFile.new()
	var err := font.load_dynamic_font(path)
	if err == OK:
		ThemeDB.fallback_font = font
		return
	err = font.load_dynamic_font(ProjectSettings.globalize_path(path))
	if err == OK:
		ThemeDB.fallback_font = font
	else:
		push_warning("CJK font load failed (err=%d)，将使用系统字体回退" % err)

## ARCH-002：具名字段 + 原子替换；ARCH-001：`die_t` 也入档，配合 main 的 tombstone 语义。
## @param units      主场景的 units 数组
## @param resources  {"gold":…, "wood":…, "food":…, "stone":…}
## @param extra      {"nextUid":int, "trainings":Array, "gameEnd":int}
## @return 是否真的落盘成功（调用方应当据此提示玩家，而不是假定成功）
func save_game(units: Array, resources: Dictionary = {}, extra: Dictionary = {}, slot := 0) -> bool:
	if not repository.begin_save(slot, int(extra.get("pendingDuels",0))): return false
	var path := save_slot_path(slot)
	var payload := snapshot(units, resources, extra, slot)
	if payload.is_empty(): return false
	if not Envelope.valid_new(payload):
		last_save_error = {"stage":"snapshot envelope", "slot":slot, "code":ERR_INVALID_DATA}
		return false
	var ok := _atomic_write(path, JSON.stringify(payload, "", true, true))
	if ok:
		print("gamesaved: %s units=%d trainings=%d nextUid=%d" % [path, payload.units.size(), payload.trainings.size(), int(extra.get("nextUid", 0))])
	return ok

func snapshot(units: Array, resources: Dictionary, extra: Dictionary, slot := -1) -> Dictionary:
	for unit in units:
		var unregistered := UnitSchema.omissions(unit)
		if not unregistered.is_empty():
			var error := {"stage":"snapshot unit fields", "code":ERR_INVALID_DATA, "slot":slot,
				"uid":int(unit.get("uid", -1)), "fields":unregistered}
			if slot >= 0: last_save_error = error
			push_warning("Save snapshot rejected: " + str(error))
			return {}
	var derived := preload("res://simulation/systems/transports.gd").snapshot_fields(units)
	var recs := []
	var by_uid := {}
	for unit in units: by_uid[int(unit.uid)] = unit
	for u in units:
		var simulation := UnitSchema.snapshot_scalars(u)
		simulation.merge(derived.get(int(u.uid),{}),true)
		simulation.merge(Relations.encode(u, by_uid), true)
		var record := UnitSchema.snapshot_record(u)
		record["simulation"] = simulation
		recs.append(record)
	var trains := snapshot_trainings(extra.get("trainings", []))
	var payload := {
		"v": SAVE_VERSION,
		"simulation": extra.get("simulation", {}),
		"kind": "save",
		"map": str(extra.get("mapId", current_map)),
		"nextUid": int(extra.get("nextUid", 0)),
		"gameEnd": int(extra.get("gameEnd", 0)),
		"units": recs,
		"trainings": trains,
		"resources": {
			"gold": float(resources.get("gold", 0.0)),
			"wood": float(resources.get("wood", 0.0)),
			"food": float(resources.get("food", 0.0)),
			"stone": float(resources.get("stone", 0.0)),
		},
		"savedAt": Time.get_datetime_string_from_system(),
		"saveName": str(extra.get("saveName", "")),
	}
	# Hash the same JSON number representation that the reader will receive.
	# JSON parses integers as floats, including values beyond the 53-bit exact range.
	payload = JSON.parse_string(JSON.stringify(_json_safe(payload), "", true, true))
	payload["checksum"] = save_checksum(payload)
	return payload

static func snapshot_trainings(trainings: Array) -> Array:
	var trains := []
	for tr in trainings:
		var rec: Dictionary = tr
		var b: Dictionary = rec.get("b", {})
		trains.append({
			"buildingUid": int(b.get("uid", -1)),
			"unit": int(rec.get("unit", -1)),
			"t": float(rec.get("t", 0.0)),
			"ticks": bool(rec.get("ticks", false)),
			"owner": int(rec.get("owner", b.get("owner", -1))),
			"cost": rec.get("cost", {}),
		})
		for field in ["aiSlot","aiToken","navalSlot","navalToken"]:
			if rec.has(field): trains.back()[field]=rec[field]
	return trains

## 存档前把非有限浮点归一，避免 JSON/校验和失败（长时间战斗的 NAN/INF 也能存）。
static func _json_safe(value):
	if value is float:
		return value if is_finite(value) else 0.0
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _json_safe(value[k])
		return out
	if value is Array:
		var out: Array = []
		for v in value:
			out.append(_json_safe(v))
		return out
	return value

## 档内校验和：只覆盖 payload（不含 checksum 本身）。
## 不能依赖 JSON.stringify(sort_keys) 的深层顺序——Godot 只保证显式序列化行为，
## 这里自己按 key 排序递归输出，数值按 1e-6 归一化，保证读写两侧完全一致。
static func _canonical_json(value) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int:
		return str(int(value))
	if value is float:
		if not is_finite(value):
			return "null"
		if float(int(value)) == value:
			return str(int(value))
		return JSON.stringify(snappedf(value, 0.000001))
	if value is String:
		return JSON.stringify(str(value))
	if value is Array:
		var parts: Array = []
		for v in value:
			parts.append(_canonical_json(v))
		return "[" + ",".join(parts) + "]"
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var parts: Array = []
		for k in keys:
			parts.append(JSON.stringify(str(k)) + ":" + _canonical_json(value[k]))
		return "{" + ",".join(parts) + "}"
	# 存档只应包含 JSON 类型；其他对象退化为字符串，至少保持稳定。
	return JSON.stringify(str(value))

static func save_canonical_text(payload: Dictionary) -> String:
	return _canonical_json(payload)

static func save_checksum(payload: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(save_canonical_text(payload).to_utf8_buffer())
	return ctx.finish().hex_encode()

static func verify_save_checksum(d: Dictionary) -> bool:
	if not d.has("checksum"):
		return false
	var copy := d.duplicate(true)
	copy.erase("checksum")
	var canon := save_canonical_text(copy)
	var ok := str(d.get("checksum", "")) == save_checksum(copy)
	if not ok:
		push_warning("save checksum mismatch (len=%d)" % canon.length())
	return ok

static func is_valid_save(d: Dictionary) -> bool:
	if not Envelope.valid(d): return false
	return verify_save_checksum(d)

static func can_rotate_save(d: Dictionary) -> bool:
	return d.has("checksum") and is_valid_save(d)

## 先写临时文件并**校验可解析**，再替换正式档 —— 任一步失败都保留前一份有效存档。
func _atomic_write(path: String, text: String) -> bool:
	return repository.commit(path,text)

func has_save() -> bool:
	return slot_catalog.has_save()

func load_save(slot := 0) -> Dictionary:
	return repository.load_slot(slot)

func save_slot_path(slot: int) -> String:
	return repository.slot_path(slot)

func save_slots() -> Array:
	return slot_catalog.entries()

func _slot_info(slot: int) -> Dictionary:
	return slot_catalog.info(slot)

static func campaign_caption(id: String) -> String:
	return CampaignSession.campaign_caption(id)

const LEVEL_REQUIRED = CampaignSession.LEVEL_REQUIRED
static func is_level_doc(data) -> bool:
	return CampaignSession.is_level_doc(data)

func list_levels() -> Array:
	return campaign.list_levels()

func next_level(map_id: String) -> Dictionary:
	return campaign.next_level(map_id)

func advance_campaign(map_id: String) -> bool:
	var entry := campaign.next_level(map_id)
	return not entry.is_empty() and change_battle(str(entry.map)) == OK

func change_battle(map_id: String, slot := -1) -> Error:
	return campaign.transition(map_id, get_tree().change_scene_to_file.bind("res://main.tscn"), slot)

func return_to_menu() -> Error:
	return campaign.leave(get_tree().change_scene_to_file.bind("res://menu.tscn"))

func _exit_tree() -> void:
	preload("res://simulation/native/math_kernel.gd").shutdown()
