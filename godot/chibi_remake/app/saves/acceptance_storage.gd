extends RefCounted
## Acceptance runs can only write a child namespace of the resolved save root.
static func configure(storage: RefCounted, args: PackedStringArray) -> Dictionary:
	if storage.has_method("configuration_error"):
		var error: String = storage.configuration_error()
		if not error.is_empty(): return {"valid":false,"error":error}
	var testing := "--selftest" in args
	var test_id := ""
	for argument in args:
		if argument.begins_with("--save-test-dir="):
			return {"valid":false,"error":"--save-test-dir is unsupported; use --save-test-id=<identifier>"}
		if argument.begins_with("--save-test-id="):
			test_id = argument.substr(15)
			var pattern := RegEx.new()
			pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$")
			if pattern.search(test_id) == null: return {"valid":false,"error":"Invalid acceptance identifier"}
			testing = true
		if argument.begins_with("--native-save="):
			if argument.substr(14) not in ["read","write","diagnose"]: return {"valid":false,"error":"Invalid acceptance phase"}
			testing = true
	var path: String = storage.resolve_path()
	if testing:
		if test_id.is_empty(): test_id = Crypto.new().generate_random_bytes(16).hex_encode()
		path = path.get_base_dir().path_join("acceptance-" + test_id).path_join("save.json")
		storage.current_path = path
		storage.pinned = true # Never fall back into a player's non-test slots.
	return {"valid":true,"path":path,"testing":testing}
