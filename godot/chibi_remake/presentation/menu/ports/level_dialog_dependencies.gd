extends "res://named_port.gd"
## Explicit sibling capabilities for level_dialog.

func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var provider = _require(_provider_menu_styles, "menu_styles")
	if provider == null: return null
	return provider._flat(bg, border, width, radius)

func _on_back() -> void:
	var provider = _require(_provider_controller, "controller")
	if provider == null: return
	provider._on_back()

func _on_level(id: String) -> void:
	var provider = _require(_provider_controller, "controller")
	if provider == null: return
	provider._on_level(id)

const CONTRACTS := {"controller": ["_on_back", "_on_level"], "menu_styles": ["_flat"]}
var _provider_controller: WeakRef
var _provider_menu_styles: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_controller = weakref(services["controller"]) if services.get("controller") != null else null
	_provider_menu_styles = weakref(services["menu_styles"]) if services.get("menu_styles") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_controller = null
	_provider_menu_styles = null
