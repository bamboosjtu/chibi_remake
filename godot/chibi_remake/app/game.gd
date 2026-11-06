extends Node
# 全局游戏状态：当前关卡 / 存档 / 关卡列表（autoload "Game"）
#
# 存档格式版本见 SAVE_VERSION（当前 8）：单位记录使用具名字段与稳定 uid，
# 资源、训练订单与各子系统快照一并写入。v1/v2/v3 旧档由 app/saves/legacy_snapshot.gd
# 兼容恢复，迁移规则见 docs/16-save-compat.md。

var current_map := "chibic1"
var pending_load := false
var pending_load_slot := 0
var startup_map_consumed := false
var startup_video_seen := false
## 读档失败时由 main 写入；主菜单显示后清空。不能静默开新局再覆盖原档。
var last_load_error := ""
## 测试钩子：让下一次 save_game 必然失败，用于验证“保存失败不丢旧档”的 UI 路径。
var force_save_failure := false
var last_save_error := {}

var storage = preload("res://app/user_storage.gd").new()
var SAVE_PATH := "user://save.json"
const SAVE_VERSION := 8
const SAVE_SLOTS := 20
const Store = preload("res://app/json_store.gd")

func _ready() -> void:
	SAVE_PATH = storage.resolve_path()
	var acceptance_run := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-test-id="):
			acceptance_run = true
			var test_id: String = argument.substr(15)
			if test_id != test_id.validate_filename(): get_tree().quit(1); return
			SAVE_PATH = SAVE_PATH.get_base_dir().path_join("acceptance-"+test_id).path_join("save.json")
			storage.current_path = SAVE_PATH
			storage.pinned = true
		if argument.begins_with("--save-test-dir="):
			SAVE_PATH = argument.substr(16).path_join("save.json")
			storage.current_path = SAVE_PATH
			storage.pinned = true
	print("SAVE LOCATION ",SAVE_PATH)
	# 干净环境/CI 的自托管 APPDATA 下 user:// 目录可能还不存在；先建目录再写 boot/save。
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	if not acceptance_run and not Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--save-test-dir=")): _migrate_legacy_userdata()
	_install_cjk_font()
	if DisplayServer.get_name() != "headless": add_child(preload("res://presentation/hud/software_cursor.gd").new())
	var f := FileAccess.open("user://boot.log", FileAccess.WRITE)
	if f != null:
		f.store_string("boot %s\nargs=%s\n" % [Time.get_datetime_string_from_system(), str(OS.get_cmdline_user_args())])
		f.close()

## Keep valid existing saves when the profile or fallback location changes.
## `legacy_directories()` only reads; it never creates the folders it looks at.
func _migrate_legacy_userdata() -> void:
	var new_dir := SAVE_PATH.get_base_dir()
	var old_dirs: Array[String] = preload("res://app/user_storage.gd").legacy_directories()
	var names := ["save.json", "save.json.bak"]
	for slot in range(1,SAVE_SLOTS+1):
		var name := "slot-%02d.json" % slot
		names.append(name);names.append(name+".bak")
	for name in names:
		var dst := new_dir.path_join(name)
		if not Store.read(dst,verify_save_checksum).is_empty(): continue
		var newest := ""
		for old_dir in old_dirs:
			if old_dir == new_dir: continue
			var src := old_dir.path_join(name)
			if Store._read(src,verify_save_checksum).is_empty(): continue
			if newest.is_empty() or FileAccess.get_modified_time(src) > FileAccess.get_modified_time(newest): newest = src
		if newest.is_empty(): continue
		if Store.commit(dst,FileAccess.get_file_as_string(newest),verify_save_checksum):
			print("migrated legacy save: ",newest)

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
	last_save_error = {}
	var path := save_slot_path(slot)
	if path.is_empty():
		last_save_error={"stage":"invalid slot","code":ERR_INVALID_PARAMETER};return false
	if force_save_failure:
		push_warning("save_game: forced failure (test hook)")
		return false
	var payload := snapshot(units, resources, extra)
	var ok := _atomic_write(path, JSON.stringify(payload, "", true, true))
	if not ok:
		last_save_error = Store.last_error.duplicate(true)
	if ok:
		print("gamesaved: %s units=%d trainings=%d nextUid=%d" % [path, payload.units.size(), payload.trainings.size(), int(extra.get("nextUid", 0))])
	return ok

func snapshot(units: Array, resources: Dictionary, extra: Dictionary) -> Dictionary:
	var recs := []
	for u in units:
		var simulation := {}
		for field in ["rolling_t","rolling_ticks","ambush_t","effect_task","effect_tasks"]:
			if u.has(field):simulation[field]=u[field]
		for field in preload("res://simulation/systems/locomotion.gd").FIELDS:
			if u.has(field): simulation[field] = u[field]
		for key in preload("res://app/saves/snapshot_fields.gd").UNIT_FIELDS:
			simulation[key] = u.get(key)
		simulation["targetUid"] = int(u.target.get("uid", -1)) if u.get("target") is Dictionary else -1
		# REQ-001：采集目标用**稳定引用**（单位 uid / 饰物格），不裸存对象。
		var gobj = u.get("gather_obj", null)
		if gobj is Dictionary and not (gobj as Dictionary).is_empty():
			if bool((gobj as Dictionary).get("decor", false)):
				simulation["gatherRef"] = {"kind": "decor", "cell": str((gobj as Dictionary).get("cell", ""))}
			elif not units.has(gobj):
				# 采尽的矿/民居可在工人返程中被清理；保留转采所需的种类和原位置。
				simulation["gatherRef"] = {"kind":"spent", "unit":int(gobj.unit), "x":float(gobj.ax), "y":float(gobj.ay)}
			else:
				simulation["gatherRef"] = {"kind": "unit", "uid": int((gobj as Dictionary).get("uid", -1))}
		for field in ["build_target", "repair_target", "board_target"]:
			var reference = u.get(field)
			simulation[field + "Uid"] = int(reference.uid) if reference is Dictionary and not reference.is_empty() and units.has(reference) else -1
		simulation["path"] = []
		for point in u.get("path", []):
			simulation.path.append([point.x, point.y])
		recs.append({
			"simulation": simulation,
			"uid": int(u.get("uid", -1)),
			"alive": bool(u.alive),
			"x": float(u.ax), "y": float(u.ay),
			"hp": float(u.hp),
			"owner": int(u.owner), "unit": int(u.unit),
			"building": bool(u.is_building),
			"mapObject": bool(u.get("map_object", false)),
			"mapIndex": int(u.get("map_index", -1)),
			"dieT": float(u.get("die_t", -1.0)),
			"state": str(u.get("state", "idle")),
			"officerIndex": int((u.get("officer", {}) as Dictionary).get("index", -1)),
		})
	var trains := []
	for tr in extra.get("trainings", []):
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
	var payload := {
		"v": SAVE_VERSION,
		"simulation": extra.get("simulation", {}),
		"kind": "save",
		"map": current_map,
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
		return int(d.get("v", 1)) < 8 # Only legacy saves predate the checksum contract.
	var copy := d.duplicate(true)
	copy.erase("checksum")
	var canon := save_canonical_text(copy)
	var ok := str(d.get("checksum", "")) == save_checksum(copy)
	if not ok:
		push_warning("save checksum mismatch (len=%d)" % canon.length())
	return ok

## 先写临时文件并**校验可解析**，再替换正式档 —— 任一步失败都保留前一份有效存档。
func _atomic_write(path: String, text: String) -> bool:
	var ok := storage.commit(path, text, verify_save_checksum)
	if ok: SAVE_PATH = storage.current_path
	return ok

func has_save() -> bool:
	for slot in range(SAVE_SLOTS+1):
		if not load_save(slot).is_empty():return true
	return false

func load_save(slot := 0) -> Dictionary:
	var path := save_slot_path(slot)
	return {} if path.is_empty() else Store.read(path, verify_save_checksum)

## Slot zero retains the existing save.json as an independent automatic/legacy save.
func save_slot_path(slot: int) -> String:
	if slot<0 or slot>SAVE_SLOTS:return ""
	return SAVE_PATH if slot==0 else SAVE_PATH.get_base_dir().path_join("slot-%02d.json" % slot)

func save_slots() -> Array:
	var out := []
	for slot in range(SAVE_SLOTS+1):
		var path := save_slot_path(slot)
		var data := load_save(slot)
		out.append({"slot":slot,"valid":not data.is_empty(),"occupied":FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"),"name":str(data.get("saveName","")),"map":str(data.get("map","")),"savedAt":str(data.get("savedAt",""))})
	return out

static func campaign_caption(id: String) -> String:
	var campaign := "刘备战役" if id.begins_with("chibil") else "曹操战役"
	return "%s · 第%d关" % [campaign,int(id.substr(6))] if id.begins_with("chibi") else "战役进度"

## ARCH-005：只把**真正的关卡**列进来。
## 以前只校验「是 Dictionary」，于是 data/officers.json 会变成一个零对象的伪关卡。
## 现在要求：显式 kind（若声明必须为 level）+ 关卡必需字段存在且类型正确。
const LEVEL_REQUIRED := ["terrainW", "terrainH", "rows", "cols", "objects", "walkable"]

static func is_level_doc(d) -> bool:
	if not (d is Dictionary):
		return false
	if d.has("kind") and str(d.kind) != "level":
		return false
	for k in LEVEL_REQUIRED:
		if not d.has(k):
			return false
	if not (d.objects is Array) or not (d.walkable is Array):
		return false
	if float(d.get("terrainW", 0)) <= 0.0 or float(d.get("terrainH", 0)) <= 0.0:
		return false
	if int(d.get("rows", 0)) <= 0 or int(d.get("cols", 0)) <= 0:
		return false
	return true

func list_levels() -> Array:
	var out := []
	var da := DirAccess.open("res://data")
	if da == null:
		return out
	for fn in da.get_files():
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/" + fn, FileAccess.READ)
		if f == null:
			continue
		var head = JSON.parse_string(f.get_as_text())
		f.close()
		# ARCH-005：坏 JSON / 数据库文件 / 缺图字段一律不能成为可点击关卡
		if not is_level_doc(head):
			push_warning("list_levels: 跳过 data/%s（不是有效关卡）" % fn)
			continue
		out.append({
			"id": fn.get_basename(),
			"name": str(head.get("name", fn)),
			"objects": (head.get("objects", []) as Array).size(),
		})
	out.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return out

## BATTLE.EXP order, including both Liu Bei 7a/7b chapters. Never cross campaigns.
func next_level(map_id: String) -> Dictionary:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/startup_briefings.json"))
	var levels: Array = catalog.get("levels", [])
	for i in range(levels.size()-1):
		if str(levels[i].map) == map_id and str(levels[i].campaign) == str(levels[i+1].campaign):
			return levels[i+1]
	return {}

func advance_campaign(map_id: String) -> bool:
	var entry := next_level(map_id)
	if entry.is_empty(): return false
	current_map = str(entry.map)
	pending_load = false
	pending_load_slot = 0
	get_tree().paused = false
	return get_tree().change_scene_to_file("res://main.tscn") == OK
