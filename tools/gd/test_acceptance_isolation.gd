extends SceneTree
class Storage extends RefCounted:
	var current_path := ""
	var pinned := false
	var resolved := false
	func resolve_path() -> String:
		resolved = true
		return "/player-slots/save.json"
func _initialize() -> void:
	var policy = preload("res://app/saves/acceptance_storage.gd")
	for arguments in [["--selftest"],["--native-save=write"],["--native-save=read","--save-test-id=repeatable"]]:
		var storage := Storage.new()
		var result: Dictionary = policy.configure(storage,PackedStringArray(arguments))
		assert(result.valid and result.testing and storage.pinned)
		assert(str(result.path).begins_with("/player-slots/acceptance-") and str(result.path).ends_with("/save.json"))
	for arguments in [["--save-test-dir=C:/player"],["--save-test-id=.."],["--save-test-id=x/../y"],["--native-save=typo"]]:
		var storage := Storage.new()
		assert(not policy.configure(storage,PackedStringArray(arguments)).valid and not storage.resolved)
	print("ACCEPTANCE ISOLATION PASS native/selftest always namespaced / traversal and arbitrary directories rejected before resolution")
	quit()
