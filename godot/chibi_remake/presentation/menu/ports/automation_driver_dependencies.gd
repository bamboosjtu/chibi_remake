extends "res://named_port.gd"
## Explicit sibling capabilities for automation_driver.

func _arrow_wiring(glyph: String) -> String:
	return _require(_provider_level_dialog, "level_dialog")._arrow_wiring(glyph)

func _first_row() -> Button:
	return _require(_provider_level_dialog, "level_dialog")._first_row()

func _on_back() -> void:
	_require(_provider_controller, "controller")._on_back()

func _on_start() -> void:
	_require(_provider_controller, "controller")._on_start()

func _portrait_status(camp: String) -> String:
	return _require(_provider_campaign_dialog, "campaign_dialog")._portrait_status(camp)

const CONTRACTS := {"campaign_dialog": ["_portrait_status"], "controller": ["_on_back", "_on_start"], "level_dialog": ["_arrow_wiring", "_first_row"]}
var _provider_campaign_dialog: WeakRef
var _provider_controller: WeakRef
var _provider_level_dialog: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign_dialog = weakref(services["campaign_dialog"]) if services.has("campaign_dialog") else null
	_provider_controller = weakref(services["controller"]) if services.has("controller") else null
	_provider_level_dialog = weakref(services["level_dialog"]) if services.has("level_dialog") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign_dialog = null
	_provider_controller = null
	_provider_level_dialog = null
