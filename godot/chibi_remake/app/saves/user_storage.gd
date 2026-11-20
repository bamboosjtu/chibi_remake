extends RefCounted
## Stable per-user storage across releases.
## Probing must not leave directories behind: the previous version created the
## fallback folder on every launch even when nothing was ever saved into it.

static func directories() -> Array[String]:
	var candidates: Array[String] = []
	var portable := portable_dir()
	if not portable.is_empty(): candidates.append(portable)
	for variable in ["LOCALAPPDATA", "APPDATA"]:
		var base := OS.get_environment(variable).replace("\\", "/")
		if not base.is_empty(): candidates.append(base.path_join("ChibiRTS/saves"))
	candidates.append(OS.get_user_data_dir())
	# Portable mode is opt-in only. Guessing it from the executable path used to
	# drop an empty `userdata/<user>` folder into the repository or the release
	# tree on every launch.
	return candidates

## Explicit opt-in: `<exe dir>/portable.txt` or `--portable` on the command line.
static func portable_dir() -> String:
	var configured := portable_configuration()
	if not configured.valid or str(configured.root).is_empty(): return ""
	var username := OS.get_environment("USERNAME").validate_filename()
	if username in ["", ".", ".."]: username = "player"
	return str(configured.root).path_join(username)

static func configuration_error() -> String:
	var configured := portable_configuration()
	return "" if configured.valid else str(configured.error)

static func portable_configuration() -> Dictionary:
	if "--storage-mode=system" in OS.get_cmdline_user_args(): return {"valid":true,"root":""}
	var exe_dir := OS.get_executable_path().get_base_dir()
	var root := ""
	for argument in Array(OS.get_cmdline_user_args()) + Array(OS.get_cmdline_args()):
		if str(argument).begins_with("--portable-root="):
			root = str(argument).substr(16)
			if root.strip_edges().is_empty(): return {"valid":false,"error":"Portable root is empty"}
	if root.is_empty() and FileAccess.file_exists(exe_dir.path_join("portable.txt")):
		root = FileAccess.get_file_as_string(exe_dir.path_join("portable.txt")).trim_prefix("\ufeff").strip_edges()
		if root.is_empty(): root = "userdata"
	if root.is_empty() and ("--portable" in OS.get_cmdline_user_args() or "--portable" in OS.get_cmdline_args()): root = exe_dir.path_join("userdata")
	return {"valid":true,"root":""} if root.is_empty() else resolve_portable_root(root,exe_dir)

static func resolve_portable_root(value: String, executable_dir: String) -> Dictionary:
	var normalized := value.strip_edges().replace("\\", "/")
	var invalid := {"valid":false,"error":"Invalid portable root: use a local absolute path or an executable-relative directory without '..'"}
	if normalized.is_empty() or normalized.begins_with("//") or normalized.contains("://"): return invalid
	if normalized.split("/").has(".."): return invalid
	for index in range(normalized.length()):
		if normalized.unicode_at(index) < 32: return invalid
	for character in ["<", ">", "\"", "|", "?", "*"]:
		if normalized.contains(character): return invalid
	var drive := RegEx.new(); drive.compile("^[A-Za-z]:/")
	if normalized.contains(":") and (drive.search(normalized) == null or normalized.substr(2).contains(":")): return invalid
	if executable_dir.length() > 1 and executable_dir[1] == ":" and normalized.begins_with("/"): return invalid
	var resolved := normalized if normalized.is_absolute_path() else executable_dir.replace("\\", "/").path_join(normalized)
	resolved = resolved.simplify_path().trim_suffix("/")
	if resolved.is_empty() or resolved == "/" or (resolved.length() == 2 and resolved[1] == ":"): return invalid
	return {"valid":true,"root":resolved}

static func writable(directory: String) -> bool:
	# Probe the nearest existing ancestor. Only JsonStore.commit creates the
	# actual save directory, so starting the game never leaves empty candidates.
	var ancestor := ProjectSettings.globalize_path(directory).simplify_path()
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor): return false
		var parent := ancestor.get_base_dir()
		if parent == ancestor or parent.is_empty(): return false
		ancestor = parent
	var probe := ancestor.path_join(".write-probe-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var file := FileAccess.open(probe,FileAccess.WRITE)
	if file != null:
		file.store_8(1); file.flush()
		var ok := file.get_error() == OK
		file.close()
		DirAccess.remove_absolute(probe)
		if ok: return true
	DirAccess.remove_absolute(probe)
	return false


var current_path := ""
var pinned := false
var attempts: Array = []

func resolve_path() -> String:
	var portable := portable_dir()
	if not portable.is_empty():
		current_path = portable.path_join("save.json")
		pinned = true
		return current_path
	for directory in directories():
		if _has_slots(directory):
			current_path = directory.path_join("save.json")
			pinned = true
			return current_path
	current_path = directories()[0].path_join("save.json")
	return current_path

static func _has_slots(directory: String) -> bool:
	if not DirAccess.dir_exists_absolute(directory): return false
	for name in DirAccess.get_files_at(directory):
		if name == "save.json" or name == "save.json.bak": return true
		var primary := name.trim_suffix(".bak")
		if primary.length() != 12 or not primary.begins_with("slot-") or not primary.ends_with(".json"): continue
		var digits := primary.substr(5, 2)
		if digits.is_valid_int() and int(digits) >= 1 and int(digits) <= 20 and primary == "slot-%02d.json" % int(digits): return true
	return false

func commit(path: String, text: String, validator: Callable, backup_validator: Callable = Callable()) -> bool:
	var store = preload("res://app/saves/json_store.gd")
	attempts.clear()
	var roots: Array[String] = [path.get_base_dir()]
	if not pinned:
		for directory in directories():
			if not roots.has(directory): roots.append(directory)
	for directory in roots:
		var target := directory.path_join(path.get_file())
		if store.commit(target, text, validator, backup_validator):
			current_path = directory.path_join("save.json")
			pinned = true
			return true
		attempts.append(store.last_error.duplicate(true))
	store.last_error["attempts"] = attempts.duplicate(true)
	return false
