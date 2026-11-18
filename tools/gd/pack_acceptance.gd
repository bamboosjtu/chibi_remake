extends SceneTree
## Package the optional acceptance scripts. The player export contains no testing resources.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var packer := PCKPacker.new()
	var error := packer.pck_start(args[1])
	if error == OK:
		for file in DirAccess.get_files_at(args[0]):
			if file.get_extension() != "gd": continue
			error = packer.add_file("res://testing/" + file, args[0].path_join(file))
			if error != OK: break
	if error == OK: error = packer.flush()
	if error == OK: print("ACCEPTANCE COMPANION PASS")
	else: printerr("Acceptance packaging failed: ", error)
	quit(0 if error == OK else 1)
