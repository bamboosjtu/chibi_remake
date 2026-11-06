extends "res://named_port.gd"
## technology: explicit callable dependencies; no battle scene reference.


func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

const CONTRACTS := {"battle_simulation": ["_feedback"]}
var _provider_battle_simulation: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
