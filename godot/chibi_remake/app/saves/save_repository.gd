extends RefCounted
signal changed
## File/slot addressing and checked write transactions.
const Store = preload("res://app/saves/json_store.gd")
const SAVE_SLOTS := 20
var storage = preload("res://app/saves/user_storage.gd").new()
var path := "user://save.json"
var last_error := {}
var force_failure := false
var validate: Callable
var backup_validate: Callable

func _init(validator: Callable, rotation_validator: Callable) -> void:
	validate=validator
	backup_validate=rotation_validator

func slot_path(slot: int) -> String:
	if slot < 0 or slot > SAVE_SLOTS: return ""
	return path if slot == 0 else path.get_base_dir().path_join("slot-%02d.json" % slot)

func begin_save(slot: int) -> bool:
	last_error={}
	if slot_path(slot).is_empty():
		last_error={"stage":"invalid slot","code":ERR_INVALID_PARAMETER}; return false
	if force_failure:
		last_error={"stage":"forced save failure","code":FAILED}; return false
	return true

func load_slot(slot: int) -> Dictionary:
	return read_slot(slot).data

func read_slot(slot: int) -> Dictionary:
	var filename := slot_path(slot)
	return {"data":{},"source":"none"} if filename.is_empty() else Store.read_with_source(filename,validate)

func commit(filename: String, text: String) -> bool:
	last_error={}
	var ok: bool = storage.commit(filename,text,validate,backup_validate)
	if ok:
		path=storage.current_path
		changed.emit()
	else: last_error=Store.last_error.duplicate(true)
	return ok



func damaged_files() -> Dictionary:
	var result := {"names":PackedStringArray(), "bytes":0}
	var folder := path.get_base_dir()
	var pattern := RegEx.new()
	pattern.compile("^(?:save|slot-[0-9]{2})[.]json[.]damaged-[0-9]+-[0-9]+$")
	for name in DirAccess.get_files_at(folder):
		if pattern.search(name) == null: continue
		var file := FileAccess.open(folder.path_join(name), FileAccess.READ)
		if file == null: continue
		result.names.append(name)
		result.bytes += file.get_length()
		file.close()
	return result

func remove_damaged_files(reviewed: PackedStringArray) -> int:
	var current: PackedStringArray = damaged_files().names
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null: return 0
	var removed := 0
	for name in reviewed:
		if current.has(name) and directory.remove(name) == OK: removed += 1
	return removed
