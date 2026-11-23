extends RefCounted
## Acceptance-only dispatcher. Loaded by main.gd only when Game.acceptance_enabled
## and a test argument is present; normal builds never reach this file.
func run(node: Node, kind: String, argument: String = "") -> void:
	match kind:
		"native_save":
			await load("res://testing/native/native_save_acceptance.gd").new().run(node, argument)
		"diag_nav":
			load("res://testing/checks/navigation_checks.gd").new(node, null)._diag_nav()
			node.get_tree().quit(0)
		"selftest":
			await load("res://testing/driver/battle_selftest.gd").new(node).run()
