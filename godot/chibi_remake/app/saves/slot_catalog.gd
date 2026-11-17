extends RefCounted
## Slot metadata cache. The injected reader returns {data, source}.
var _cache := {}
var _load: Callable
var _path: Callable
var _limit: int

func _init(reader: Callable, address: Callable, limit: int) -> void:
	_load=reader; _path=address; _limit=limit

func invalidate() -> void:
	_cache.clear()

func has_save() -> bool:
	for slot in range(_limit+1):
		if info(slot).valid: return true
	return false

func entries() -> Array:
	var result := []
	for slot in range(_limit+1): result.append(info(slot).duplicate())
	return result

func info(slot: int) -> Dictionary:
	var path: String = _path.call(slot)
	var signature := []
	for file in [path,path+".bak"]:
		var reader := FileAccess.open(file, FileAccess.READ)
		if reader == null:
			signature.append([-1,0,""]); continue
		var length := reader.get_length()
		reader.close()
		var digest := FileAccess.get_sha256(file) if length <= preload("res://app/saves/json_limits.gd").MAX_BYTES else "oversized"
		signature.append([FileAccess.get_modified_time(file),length,digest])
	if _cache.has(path) and _cache[path].signature == signature: return _cache[path].info.duplicate()
	var loaded: Dictionary = _load.call(slot)
	var data: Dictionary = loaded.data
	var source: String = loaded.source
	var info := {"slot":slot,"valid":not data.is_empty(),"occupied":signature[0][0]!=-1 or signature[1][0]!=-1,"source":source,"name":str(data.get("saveName","")),"map":str(data.get("map","")),"savedAt":str(data.get("savedAt",""))}
	_cache[path] = {"signature":signature,"info":info}
	return info.duplicate()

