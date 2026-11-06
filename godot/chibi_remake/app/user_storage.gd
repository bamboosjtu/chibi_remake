extends RefCounted
## Stable per-user storage across releases.
## Probing must not leave directories behind: the previous version created the
## fallback folder on every launch even when nothing was ever saved into it.

static func save_path() -> String:
	var candidates := directories()
	for directory in candidates:
		if writable(directory):
			if directory == candidates.back(): push_warning("User profile is not writable; save location: "+directory)
			return directory.path_join("save.json")
	return candidates[0].path_join("save.json")

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
	if "--storage-mode=system" in OS.get_cmdline_user_args(): return ""
	var exe_dir := OS.get_executable_path().get_base_dir()
	var root := ""
	for argument in Array(OS.get_cmdline_user_args()) + Array(OS.get_cmdline_args()):
		if str(argument).begins_with("--portable-root="): root = str(argument).substr(16)
	if root.is_empty() and FileAccess.file_exists(exe_dir.path_join("portable.txt")):
		var configured := FileAccess.get_file_as_string(exe_dir.path_join("portable.txt")).strip_edges()
		root = exe_dir.path_join(configured if not configured.is_empty() else "userdata").simplify_path()
	if root.is_empty() and ("--portable" in OS.get_cmdline_user_args() or "--portable" in OS.get_cmdline_args()): root = exe_dir.path_join("userdata")
	if root.is_empty(): return ""
	var username := OS.get_environment("USERNAME").validate_filename()
	return root.path_join(username if not username.is_empty() else "player")

## Read-only list of places earlier builds wrote saves to. Nothing here is
## created or probed, so migration never resurrects the folder it reads from.
static func legacy_directories() -> Array[String]:
	var sources := directories()
	var exe_dir := OS.get_executable_path().get_base_dir()
	# Published builds ran from `release/versions/<version>/`, one level deeper.
	if exe_dir.get_base_dir().get_file() == "versions": exe_dir = exe_dir.get_base_dir().get_base_dir()
	var username := OS.get_environment("USERNAME").validate_filename()
	sources.append(exe_dir.path_join("userdata").path_join(username if not username.is_empty() else "player"))
	sources.append(OS.get_user_data_dir().get_base_dir().path_join("Chibi Verifier"))
	return sources

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
		if name == "save.json" or name == "save.json.bak" or name.begins_with("slot-"): return true
	return false

func commit(path: String, text: String, validator: Callable) -> bool:
	var store = preload("res://app/json_store.gd")
	attempts.clear()
	var roots: Array[String] = [path.get_base_dir()]
	if not pinned:
		for directory in directories():
			if not roots.has(directory): roots.append(directory)
	for directory in roots:
		var target := directory.path_join(path.get_file())
		if store.commit(target, text, validator):
			current_path = directory.path_join("save.json")
			pinned = true
			return true
		attempts.append(store.last_error.duplicate(true))
	store.last_error["attempts"] = attempts.duplicate(true)
	return false
