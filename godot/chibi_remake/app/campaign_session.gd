extends RefCounted
## Campaign selection and pending-load state; scene navigation remains in Game.
var current_map := "chibic1"
var pending_load := false
var pending_load_slot := 0
var startup_map_consumed := false
var startup_load_consumed := false
var startup_video_seen := false
var last_load_error := ""

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

func advance(map_id: String) -> bool:
	var entry := next_level(map_id)
	if entry.is_empty(): return false
	current_map=str(entry.map)
	pending_load=false
	pending_load_slot=0
	return true
