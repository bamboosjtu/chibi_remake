extends SceneTree
## Package the optional acceptance scripts. The player export contains no testing resources.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var packer := PCKPacker.new()
	var error := packer.pck_start(args[1])
	var counter := [0]
	if error == OK: error = _add_tree(packer, args[0], "", counter)
	if error == OK: error = packer.flush()
	if error == OK: print("ACCEPTANCE COMPANION PASS %d scripts" % counter[0])
	else: printerr("Acceptance packaging failed: ", error)
	quit(0 if error == OK else 1)

func _add_tree(packer: PCKPacker, root: String, relative: String, count: Array) -> Error:
	var dir_path := root if relative == "" else root.path_join(relative)
	var dir := DirAccess.open(dir_path)
	if dir == null: return ERR_CANT_OPEN
	var files := dir.get_files()
	files.sort()
	for file in files:
		if file.get_extension() != "gd": continue
		var target := "res://testing/" + (file if relative == "" else relative.path_join(file))
		var error := packer.add_file(target, dir_path.path_join(file))
		if error != OK: return error
		count[0] += 1
	var directories := dir.get_directories()
	directories.sort()
	for sub in directories:
		var error := _add_tree(packer, root, sub if relative == "" else relative.path_join(sub), count)
		if error != OK: return error
	return OK
