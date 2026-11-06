extends "res://named_port.gd"
## Explicit sibling capabilities for hud_layout.

func _apply_metrics_original(vp: Vector2, s: float) -> void:
	_require(_provider_legacy_layout, "legacy_layout")._apply_metrics_original(vp, s)

func _layout_cmd_art() -> void:
	_require(_provider_command_art, "command_art")._layout_cmd_art()

func set_zoom() -> void:
	_require(_provider_camera_controller, "camera_controller").set_zoom()

const CONTRACTS := {"camera_controller": ["set_zoom"], "command_art": ["_layout_cmd_art"], "legacy_layout": ["_apply_metrics_original"]}
var _provider_camera_controller: WeakRef
var _provider_command_art: WeakRef
var _provider_legacy_layout: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.has("camera_controller") else null
	_provider_command_art = weakref(services["command_art"]) if services.has("command_art") else null
	_provider_legacy_layout = weakref(services["legacy_layout"]) if services.has("legacy_layout") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_art = null
	_provider_legacy_layout = null
