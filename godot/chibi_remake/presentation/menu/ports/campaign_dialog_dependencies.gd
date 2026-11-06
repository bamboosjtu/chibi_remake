extends "res://named_port.gd"
## Explicit sibling capabilities for campaign_dialog.

func _gold_button(text: String, w: float, h: float, fs: int, cb: Callable) -> Button:
	return _require(_provider_menu_styles, "menu_styles")._gold_button(text, w, h, fs, cb)

func _on_back() -> void:
	_require(_provider_controller, "controller")._on_back()

func _on_campaign_confirm() -> void:
	_require(_provider_controller, "controller")._on_campaign_confirm()

func _wood_frame(sel: bool, pad: int) -> StyleBoxFlat:
	return _require(_provider_menu_styles, "menu_styles")._wood_frame(sel, pad)

func _wood_plate() -> StyleBoxFlat:
	return _require(_provider_menu_styles, "menu_styles")._wood_plate()

const CONTRACTS := {"controller": ["_on_back", "_on_campaign_confirm"], "menu_styles": ["_gold_button", "_wood_frame", "_wood_plate"]}
var _provider_controller: WeakRef
var _provider_menu_styles: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_controller = weakref(services["controller"]) if services.has("controller") else null
	_provider_menu_styles = weakref(services["menu_styles"]) if services.has("menu_styles") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_controller = null
	_provider_menu_styles = null
