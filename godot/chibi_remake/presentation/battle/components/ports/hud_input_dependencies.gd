extends "res://named_port.gd"
## Explicit sibling capabilities for hud_input.

func _act_close_officer_pick() -> void:
	_require(_provider_selection_info, "selection_info")._act_close_officer_pick()

func _act_open_officer_pick() -> void:
	_require(_provider_selection_info, "selection_info")._act_open_officer_pick()

func _close_art_sub() -> void:
	_require(_provider_command_art, "command_art")._close_art_sub()

func _handle_cmd_key(k: InputEventKey) -> bool:
	return _require(_provider_command_art, "command_art")._handle_cmd_key(k)

func _minimap_navigate(screen_position: Vector2) -> void:
	_require(_provider_camera_controller, "camera_controller")._minimap_navigate(screen_position)

func _on_cmd(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._on_cmd(i)

func _on_cmd_page(dir: int) -> bool:
	return _require(_provider_command_model, "command_model")._on_cmd_page(dir)

func _on_hotkey(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._on_hotkey(i)

func _sel_state_text() -> String:
	return _require(_provider_selection_info, "selection_info")._sel_state_text()

func _set_art_state(index: int, state: int) -> void:
	_require(_provider_command_art, "command_art")._set_art_state(index, state)

const CONTRACTS := {"camera_controller": ["_minimap_navigate"], "command_actions": ["_on_cmd", "_on_hotkey"], "command_art": ["_close_art_sub", "_handle_cmd_key", "_set_art_state"], "command_model": ["_on_cmd_page"], "selection_info": ["_act_close_officer_pick", "_act_open_officer_pick", "_sel_state_text"]}
var _provider_camera_controller: WeakRef
var _provider_command_actions: WeakRef
var _provider_command_art: WeakRef
var _provider_command_model: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.has("camera_controller") else null
	_provider_command_actions = weakref(services["command_actions"]) if services.has("command_actions") else null
	_provider_command_art = weakref(services["command_art"]) if services.has("command_art") else null
	_provider_command_model = weakref(services["command_model"]) if services.has("command_model") else null
	_provider_selection_info = weakref(services["selection_info"]) if services.has("selection_info") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_actions = null
	_provider_command_art = null
	_provider_command_model = null
	_provider_selection_info = null
