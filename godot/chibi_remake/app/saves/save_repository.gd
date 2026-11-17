extends RefCounted
signal changed
## File/slot addressing and checked write transactions.
const Store = preload("res://app/json_store.gd")
const SAVE_SLOTS := 20
var storage = preload("res://app/user_storage.gd").new()
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

func begin_save(slot: int, pending_duels: int) -> bool:
	last_error={}
	if pending_duels > 0:
		last_error={"stage":"unsettled duel; use session save command","code":ERR_BUSY}; return false
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

