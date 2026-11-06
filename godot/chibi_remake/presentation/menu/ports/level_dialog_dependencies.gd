extends "res://named_port.gd"
## Explicit sibling capabilities for level_dialog.

func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	return _require(_provider_menu_styles, "menu_styles")._flat(bg, border, width, radius)

func _on_back() -> void:
	_require(_provider_controller, "controller")._on_back()

func _on_level(id: String) -> void:
	_require(_provider_controller, "controller")._on_level(id)

const CONTRACTS := {"controller": ["_on_back", "_on_level"], "menu_styles": ["_flat"]}
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
