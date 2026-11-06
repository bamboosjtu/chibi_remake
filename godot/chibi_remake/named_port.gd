extends RefCounted
## Weak provider lifetime guard shared by every explicit command/dependency port.
static func require_provider(reference: WeakRef, provider: String) -> Object:
	var target: Object = reference.get_ref() if reference != null else null
	if target == null:
		preload("res://composition_contract.gd").abort_if_broken("expired port", [{"provider":provider,"method":"provider lifetime"}])
	return target

func _require(reference: WeakRef, provider: String) -> Object:
	return require_provider(reference, provider)

func validate_services(services: Dictionary, contracts: Dictionary) -> Array:
	var missing: Array = []
	for provider in contracts:
		for method in contracts[provider]:
			if services.get(provider) == null or not services[provider].has_method(method):
				missing.append({"provider": provider, "method": method})
	return missing
