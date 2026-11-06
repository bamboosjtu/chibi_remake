extends "res://named_port.gd"
## Explicit sibling capabilities for legacy_layout.

func _decorate_frame(panel: Panel, border: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._decorate_frame(panel, border)

func _layout_cmd_art() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._layout_cmd_art()

func _layout_status_labels(vp: Vector2, s: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._layout_status_labels(vp, s)

func _pin_right(c: Control, dist_right: float, w: float, top: float, h: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._pin_right(c, dist_right, w, top, h)

func _place_left(c: Control, x: float, y: float, w: float, h: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._place_left(c, x, y, w, h)

func clamp_camera() -> void:
	var provider = _require(_provider_camera_controller, "camera_controller")
	if provider == null: return
	provider.clamp_camera()

const CONTRACTS := {"camera_controller": ["clamp_camera"], "command_art": ["_layout_cmd_art"], "hud_layout": ["_decorate_frame", "_layout_status_labels", "_pin_right", "_place_left"]}
var _provider_camera_controller: WeakRef
var _provider_command_art: WeakRef
var _provider_hud_layout: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.get("camera_controller") != null else null
	_provider_command_art = weakref(services["command_art"]) if services.get("command_art") != null else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.get("hud_layout") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_art = null
	_provider_hud_layout = null
