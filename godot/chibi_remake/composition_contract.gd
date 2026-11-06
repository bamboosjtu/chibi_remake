extends RefCounted
## Explicit named-provider contracts. There is no method registration/dispatch table.
static var reports: Dictionary = {}

static func wire(services: Dictionary, label: String, access: Dictionary = {}) -> Dictionary:
	var missing: Array = []
	var scripts := {}
	var required := {}
	for key in services:
		if services[key] == null:
			missing.append({"provider": key, "method": "provider lifetime"})
			continue
		var script = services[key].get_script()
		scripts[key] = script.resource_path if script != null else "builtin://" + services[key].get_class()
		var ports = services[key].get("ports")
		if ports != null:
			for failure in ports.connect_services(services):
				failure["owner"] = key
				missing.append(failure)
			for provider in ports.CONTRACTS:
				for method in ports.CONTRACTS[provider]: required[provider + "." + method] = provider
	for key in access:
		for failure in access[key].connect_services(services):
			failure["owner"] = key
			missing.append(failure)
		for provider in access[key].CONTRACTS:
			for method in access[key].CONTRACTS[provider]: required[provider + "." + method] = provider
	reports[label] = {"services": scripts, "owners": required, "methods": required.keys(), "missing": missing}
	abort_if_broken(label, missing)
	return reports[label]

static func abort_if_broken(label: String, missing: Array) -> bool:
	if missing.is_empty(): return false
	push_error(label + ": explicit port contract failed: " + JSON.stringify(missing))
	var loop := Engine.get_main_loop()
	if loop is SceneTree: loop.quit(1)
	return true
