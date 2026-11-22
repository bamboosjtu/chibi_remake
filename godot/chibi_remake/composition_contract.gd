extends RefCounted
## Explicit named-provider contracts. There is no method registration/dispatch table.
static var reports: Dictionary = {}

static func wire(services: Dictionary, label: String, fail_fast := true) -> Dictionary:
	var missing: Array = []
	var scripts := {}
	for key in services:
		var service: Object = services[key]
		if service == null:
			missing.append({"owner":label, "provider":key})
			continue
		var script: Script = service.get_script()
		if script == null:
			missing.append({"owner":label, "provider":key, "method":"script"})
			continue
		scripts[key] = script.resource_path
		for field in service.get_property_list():
			var name := str(field.name)
			var required := name.begins_with("_dep_")
			var peer := name.trim_prefix("_dep_") if required else name.trim_prefix("_")
			if not required and (peer == name or not services.has(peer)): continue
			if services.get(peer) == null or not is_same(service.get(name), services[peer]):
				missing.append({"owner":key, "provider":peer, "method":"concrete collaborator"})
	reports[label] = {"services":scripts, "missing":missing}
	if fail_fast: abort_if_broken(label, missing)
	return reports[label]

static func abort_if_broken(label: String, missing: Array) -> bool:
	if missing.is_empty(): return false
	push_error(label + ": contract validation failed: " + JSON.stringify(missing) + "; shutdown requested (exit 1)")
	var loop := Engine.get_main_loop()
	if loop is SceneTree: loop.quit(1)
	return true
