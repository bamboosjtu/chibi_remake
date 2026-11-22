extends SceneTree

func _initialize() -> void:
	var failures := inspect("res://")
	if failures == 0: print("RUNTIME SCRIPTS PASS all runtime GDScript resources compile")
	quit(0 if failures == 0 else 1)

func inspect(directory: String) -> int:
	var failures := 0
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			var script = load(directory.path_join(file))
			if script == null or not script.can_instantiate(): failures += 1
	for folder in DirAccess.get_directories_at(directory):
		if folder.begins_with(".") or folder in ["art", "assets", "media", "data", "addons"]: continue
		failures += inspect(directory.path_join(folder))
	return failures
