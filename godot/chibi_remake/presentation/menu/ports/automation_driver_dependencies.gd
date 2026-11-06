extends "res://named_port.gd"
## Explicit sibling capabilities for automation_driver.

func _arrow_wiring(glyph: String) -> String:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return ""
	return provider._arrow_wiring(glyph)

func _first_row() -> Button:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return null
	return provider._first_row()

func _on_back() -> void:
	var provider = _require(_provider_controller, "controller")
	if provider == null: return
	provider._on_back()

func _on_start() -> void:
	var provider = _require(_provider_controller, "controller")
	if provider == null: return
	provider._on_start()

func _portrait_status(camp: String) -> String:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return ""
	return provider._portrait_status(camp)

const CONTRACTS := {"campaign_dialog": ["_portrait_status"], "controller": ["_on_back", "_on_start"], "level_dialog": ["_arrow_wiring", "_first_row"]}
var _provider_campaign_dialog: WeakRef
var _provider_controller: WeakRef
var _provider_level_dialog: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign_dialog = weakref(services["campaign_dialog"]) if services.get("campaign_dialog") != null else null
	_provider_controller = weakref(services["controller"]) if services.get("controller") != null else null
	_provider_level_dialog = weakref(services["level_dialog"]) if services.get("level_dialog") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign_dialog = null
	_provider_controller = null
	_provider_level_dialog = null
