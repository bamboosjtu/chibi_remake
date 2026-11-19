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
	var fixture := OS.get_environment("LOCALAPPDATA").path_join("storage-slot-fixture")
	assert(DirAccess.make_dir_recursive_absolute(fixture) == OK)
	for name in ["slot-01.json.tmp-1-1", "slot-01.json.damaged-1-1", "slot-not-a-save"]:
		var file := FileAccess.open(fixture.path_join(name), FileAccess.WRITE)
		file.store_string("residue")
		file.close()
	assert(not storage._has_slots(fixture), "Failed-write residue must not pin a fresh user's storage root")
	var backup := FileAccess.open(fixture.path_join("slot-20.json.bak"), FileAccess.WRITE)
	backup.store_string("{}")
	backup.close()
	assert(storage._has_slots(fixture), "A legitimate backup must retain its storage root")
	for name in DirAccess.get_files_at(fixture): DirAccess.remove_absolute(fixture.path_join(name))
	assert(DirAccess.remove_absolute(fixture) == OK)
	print("USER STORAGE PASS twenty probes / no directory residue / file ancestor rejected / explicit portable")
	quit()
