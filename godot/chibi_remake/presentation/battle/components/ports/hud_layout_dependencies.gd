extends "res://named_port.gd"
## Explicit sibling capabilities for hud_layout.

func _apply_metrics_original(vp: Vector2, s: float) -> void:
	var provider = _require(_provider_legacy_layout, "legacy_layout")
	if provider == null: return
	provider._apply_metrics_original(vp, s)

func _layout_cmd_art() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._layout_cmd_art()

func set_zoom() -> void:
	var provider = _require(_provider_camera_controller, "camera_controller")
	if provider == null: return
	provider.set_zoom()

const CONTRACTS := {"camera_controller": ["set_zoom"], "command_art": ["_layout_cmd_art"], "legacy_layout": ["_apply_metrics_original"]}
var _provider_camera_controller: WeakRef
var _provider_command_art: WeakRef
var _provider_legacy_layout: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.get("camera_controller") != null else null
	_provider_command_art = weakref(services["command_art"]) if services.get("command_art") != null else null
	_provider_legacy_layout = weakref(services["legacy_layout"]) if services.get("legacy_layout") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_art = null
	_provider_legacy_layout = null
