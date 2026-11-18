extends RefCounted
## Campaign selection and pending-load state; scene navigation remains in Game.
var current_map := "chibic1"
var pending_load := false
var pending_load_slot := 0
var startup_map_consumed := false
var startup_load_consumed := false
var startup_video_seen := false
var last_load_error := ""
var catalog := preload("res://app/level_catalog.gd").new()

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
	return catalog.levels()

## Campaign progression follows the generated BATTLE.EXP order, including 7a/7b.
func next_level(map_id: String) -> Dictionary:
	return catalog.next_level(map_id)

func advance(map_id: String) -> bool:
	var entry := next_level(map_id)
	if entry.is_empty(): return false
	_select(str(entry.map), -1)
	return true

func transition(map_id: String, change_scene: Callable, slot := -1) -> Error:
	if not catalog.contains(map_id): return ERR_INVALID_PARAMETER
	return _change(map_id,change_scene,slot)

func restore_battle(map_id: String, install: Callable) -> bool:
	if not catalog.contains(map_id) or not install.call(): return false
	_select(map_id, -1)
	last_load_error = ""
	return true

func leave(change_scene: Callable) -> Error:
	return _change(current_map,change_scene,-1,false)

func _change(map_id: String, change_scene: Callable, slot: int, clear_error := true) -> Error:
	if not change_scene.is_valid(): return ERR_INVALID_PARAMETER
	var previous := [current_map, pending_load, pending_load_slot, last_load_error]
	_select(map_id, slot)
	if clear_error: last_load_error = ""
	var error := int(change_scene.call())
	if error != OK:
		current_map = previous[0]; pending_load = previous[1]
		pending_load_slot = previous[2]; last_load_error = previous[3]
	return error as Error

func _select(map_id: String, slot: int) -> void:
	current_map = map_id; pending_load = slot >= 0
	pending_load_slot = maxi(0, slot)
