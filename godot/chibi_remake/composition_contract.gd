extends RefCounted
## Explicit named-provider contracts. There is no method registration/dispatch table.
static var reports: Dictionary = {}

static func wire(services: Dictionary, label: String, access: Dictionary = {}) -> Dictionary:
	var missing: Array = []
	var scripts := {}
	var required := {}
	for key in services:
		scripts[key] = services[key].get_script().resource_path
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
	reports[label] = {"services": scripts, "owners": required, "methods": required.keys(), "conflicts": [], "missing": missing}
	abort_if_broken(label, [], missing)
	return reports[label]

static func abort_if_broken(label: String, conflicts: Array, missing: Array) -> bool:
	if conflicts.is_empty() and missing.is_empty(): return false
	push_error(label + ": explicit port contract failed: " + JSON.stringify(missing))
	var loop := Engine.get_main_loop()
	if loop is SceneTree: loop.quit(1)
	return true
