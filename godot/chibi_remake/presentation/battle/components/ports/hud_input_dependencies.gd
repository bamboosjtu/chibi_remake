extends "res://named_port.gd"
## Explicit sibling capabilities for hud_input.

func _act_close_officer_pick() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._act_close_officer_pick()

func _act_open_officer_pick() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._act_open_officer_pick()

func _close_art_sub() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._close_art_sub()

func _handle_cmd_key(k: InputEventKey) -> bool:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return false
	return provider._handle_cmd_key(k)

func _minimap_navigate(screen_position: Vector2) -> void:
	var provider = _require(_provider_camera_controller, "camera_controller")
	if provider == null: return
	provider._minimap_navigate(screen_position)

func _on_cmd(i: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._on_cmd(i)

func _on_cmd_page(dir: int) -> bool:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return false
	return provider._on_cmd_page(dir)

func _on_hotkey(i: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._on_hotkey(i)

func _sel_state_text() -> String:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return ""
	return provider._sel_state_text()

func _set_art_state(index: int, state: int) -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._set_art_state(index, state)

const CONTRACTS := {"camera_controller": ["_minimap_navigate"], "command_actions": ["_on_cmd", "_on_hotkey"], "command_art": ["_close_art_sub", "_handle_cmd_key", "_set_art_state"], "command_model": ["_on_cmd_page"], "selection_info": ["_act_close_officer_pick", "_act_open_officer_pick", "_sel_state_text"]}
var _provider_camera_controller: WeakRef
var _provider_command_actions: WeakRef
var _provider_command_art: WeakRef
var _provider_command_model: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.get("camera_controller") != null else null
	_provider_command_actions = weakref(services["command_actions"]) if services.get("command_actions") != null else null
	_provider_command_art = weakref(services["command_art"]) if services.get("command_art") != null else null
	_provider_command_model = weakref(services["command_model"]) if services.get("command_model") != null else null
	_provider_selection_info = weakref(services["selection_info"]) if services.get("selection_info") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_actions = null
	_provider_command_art = null
	_provider_command_model = null
	_provider_selection_info = null
