extends "res://named_port.gd"
## campaign: explicit callable dependencies; no battle scene reference.


func _show_end(kind: int) -> void:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return
	provider._show_end(kind)

const CONTRACTS := {"campaign": ["_show_end"]}
var _provider_campaign: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign = weakref(services["campaign"]) if services.get("campaign") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign = null
