extends "res://named_port.gd"
## Explicit sibling capabilities for command_actions.

func _refresh_cmd_art() -> void:
	_require(_provider_command_art, "command_art")._refresh_cmd_art()

func _refresh_cmd_panel() -> void:
	_require(_provider_command_model, "command_model")._refresh_cmd_panel()

func _selected_building() -> Dictionary:
	return _require(_provider_selection_info, "selection_info")._selected_building()

const CONTRACTS := {"command_art": ["_refresh_cmd_art"], "command_model": ["_refresh_cmd_panel"], "selection_info": ["_selected_building"]}
var _provider_command_art: WeakRef
var _provider_command_model: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_art = weakref(services["command_art"]) if services.has("command_art") else null
	_provider_command_model = weakref(services["command_model"]) if services.has("command_model") else null
	_provider_selection_info = weakref(services["selection_info"]) if services.has("selection_info") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_art = null
	_provider_command_model = null
	_provider_selection_info = null
