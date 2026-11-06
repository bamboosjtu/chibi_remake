extends RefCounted
static var last_error: Dictionary = {}
static var context: Dictionary = {}

static func _fail(stage: String, code: int = FAILED) -> bool:
	last_error = context.duplicate(true)
	last_error.merge({"stage": stage, "code": code}, true)
	var temporary: String = str(context.get("temporary", ""))
	if not temporary.is_empty() and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	push_warning("save failed: " + JSON.stringify(last_error))
	return false
## 崩溃恢复协议：提交失败时旧文件保留在主文件或 .bak 中。
static func _read(path: String, validator: Callable = Callable()) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		return {}
	var value = parser.data
	if not value is Dictionary or (validator.is_valid() and not validator.call(value)):
		return {}
	return value

static func read(path: String, validator: Callable = Callable()) -> Dictionary:
	var value := _read(path, validator)
	if not value.is_empty():
		return value
	return _read(path + ".bak", validator)

static func commit(path: String, text: String, validator: Callable = Callable()) -> bool:
	last_error = {}
	path = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	context = {"path": path, "directory": path.get_base_dir(), "temporary": ""}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _fail("serialize", parser.get_error_line())
	if validator.is_valid() and not validator.call(parser.data):
		return _fail("validate payload")
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK: return _fail("create directory", directory_error)
	# 唯一临时名：两个实例同时保存不会互踩；Godot 还没有 fsync，
	# flush + rename 后读回校验是当前 API 能得到的最强保证。
	var tmp_path := path + ".tmp-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	context.temporary = tmp_path
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return _fail("open temporary", FileAccess.get_open_error())
	f.store_string(text)
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK or _read(tmp_path, validator).is_empty():
		return _fail("verify temporary", error)
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return _fail("open directory", DirAccess.get_open_error())
	var name := path.get_file()
	var damaged := ""
	if d.file_exists(name):
		# 仅当当前档有效才可撤下备份；损坏主档不能覆盖有效备份。
		if _read(path, validator).is_empty():
			# 没有备份的损坏旧档也必须允许重新保存，否则会永久困在“保存失败”。
			# 保留原始字节供诊断，不覆盖现有的有效备份。
			damaged = name + ".damaged-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
			if d.rename(name, damaged) != OK:
				return _fail("quarantine damaged primary")
		else:
			if d.file_exists(name + ".bak") and d.remove(name + ".bak") != OK:
				return _fail("replace backup")
			if d.rename(name, name + ".bak") != OK:
				return _fail("backup primary")
	if d.rename(tmp_path.get_file(), name) != OK:
		if not d.file_exists(name):
			if not _read(path + ".bak", validator).is_empty(): d.rename(name + ".bak", name)
			elif damaged != "": d.rename(damaged, name)
		return _fail("commit temporary")
	# rename 成功也可能因磁盘/文件系统问题读到截断内容；提交后必须读回。
	if _read(path, validator).is_empty():
		if not _read(path + ".bak", validator).is_empty(): d.rename(name + ".bak", name)
		elif damaged != "": d.rename(damaged, name)
		return _fail("verify committed")
	# 保留已验证的上一档，供下一次加载发现损坏时恢复。
	return true
