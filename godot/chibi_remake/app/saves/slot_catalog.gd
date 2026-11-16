extends RefCounted
## Slot metadata cache. All file reads go through the injected repository reader.
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
		signature.append([FileAccess.get_modified_time(file),reader.get_length()] if reader != null else [-1,0])
	if _cache.has(path) and _cache[path].signature == signature: return _cache[path].info.duplicate()
	var data: Dictionary = _load.call(slot)
	var info := {"slot":slot,"valid":not data.is_empty(),"occupied":signature[0][0]!=-1 or signature[1][0]!=-1,"name":str(data.get("saveName","")),"map":str(data.get("map","")),"savedAt":str(data.get("savedAt",""))}
	_cache[path] = {"signature":signature,"info":info}
	return info.duplicate()

