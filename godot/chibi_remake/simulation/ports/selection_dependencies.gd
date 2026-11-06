extends "res://named_port.gd"
## selection: explicit callable dependencies; no battle scene reference.


func _yield_of(unit_id: int) -> String:
	return _require(_provider_harvest_orders, "harvest_orders")._yield_of(unit_id)

const CONTRACTS := {"harvest_orders": ["_yield_of"]}
var _provider_harvest_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_harvest_orders = null
