extends "res://named_port.gd"
## The cinematic controller consumes a resolved result, never simulation rules.

const CONTRACTS := {}

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	pass
