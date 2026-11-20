extends SceneTree
## Package the optional acceptance scripts. The player export contains no testing resources.
const REQUIRED := [
	"automation/acceptance_hook.gd", "automation/menu_harness.gd",
	"benchmark/full_battle_benchmark.gd", "checks/checks_base.gd",
	"checks/gathering_checks.gd", "checks/groups_checks.gd",
	"checks/navigation_checks.gd", "checks/technology_checks.gd",
	"driver/battle_selftest.gd", "native/native_save_acceptance.gd",
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	for relative in REQUIRED:
		if not FileAccess.file_exists(args[0].path_join(relative)):
			printerr("Acceptance companion is missing ", relative)
			quit(1)
			return
	var packer := PCKPacker.new()
	var error := packer.pck_start(args[1])
	if error == OK:
		for relative in REQUIRED:
			error = packer.add_file("res://testing/" + relative, args[0].path_join(relative))
			if error != OK: break
	if error == OK: error = packer.flush()
	if error == OK:
		print("ACCEPTANCE COMPANION PASS %d scripts" % REQUIRED.size())
	else:
		printerr("Acceptance packaging failed: ", error)
	quit(0 if error == OK else 1)
