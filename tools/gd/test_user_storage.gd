extends SceneTree

func _initialize() -> void:
	var storage = preload("res://app/user_storage.gd")
	var directory := OS.get_environment("LOCALAPPDATA").path_join("not-created/nested/saves")
	for attempt in range(20): assert(storage.writable(directory))
	assert(not DirAccess.dir_exists_absolute(directory.get_base_dir().get_base_dir()))
	assert(not storage.writable("res://project.godot/impossible"))
	var portable: String = storage.portable_dir()
	if portable.is_empty():
		for candidate in storage.directories():
			assert(not candidate.contains("/userdata/"), "Portable storage requires explicit opt-in")
	else:
		assert(storage.directories()[0] == portable, "Explicit portable mode must take precedence")
	print("USER STORAGE PASS twenty probes / no directory residue / file ancestor rejected / explicit portable")
	quit()
