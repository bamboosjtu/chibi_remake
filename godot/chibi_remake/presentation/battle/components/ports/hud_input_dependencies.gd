extends "res://named_port.gd"
## Explicit sibling capabilities for hud_input.

func _close_art_sub() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._close_art_sub()

func _handle_cmd_key(k: InputEvent) -> bool:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return false
	return provider._handle_cmd_key(k)

func _minimap_navigate(screen_position: Vector2) -> void:
	var provider = _require(_provider_camera_controller, "camera_controller")
	if provider == null: return
	provider._minimap_navigate(screen_position)

func _sel_state_text() -> String:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return ""
	return provider._sel_state_text()

func _set_art_state(index: int, state: int) -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._set_art_state(index, state)

const CONTRACTS := {"camera_controller": ["_minimap_navigate"], "command_art": ["_close_art_sub", "_handle_cmd_key", "_set_art_state"], "selection_info": ["_sel_state_text"]}
var _provider_camera_controller: WeakRef
var _provider_command_art: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.get("camera_controller") != null else null
	_provider_command_art = weakref(services["command_art"]) if services.get("command_art") != null else null
	_provider_selection_info = weakref(services["selection_info"]) if services.get("selection_info") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_art = null
	_provider_selection_info = null
