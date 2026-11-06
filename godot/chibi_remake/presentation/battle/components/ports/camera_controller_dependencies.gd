extends "res://named_port.gd"
## Explicit sibling capabilities for camera_controller.

const CONTRACTS := {}

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	pass
