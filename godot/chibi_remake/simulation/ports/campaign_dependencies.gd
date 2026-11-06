extends "res://named_port.gd"
## campaign: explicit callable dependencies; no battle scene reference.


func _show_end(kind: int) -> void:
	_require(_provider_campaign, "campaign")._show_end(kind)

const CONTRACTS := {"campaign": ["_show_end"]}
var _provider_campaign: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign = weakref(services["campaign"]) if services.has("campaign") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign = null
