extends "res://named_port.gd"
## Explicit sibling capabilities for selection_info.

func _layout_status_labels(vp: Vector2, s: float) -> void:
	_require(_provider_hud_layout, "hud_layout")._layout_status_labels(vp, s)

func _refresh_cmd_panel() -> void:
	_require(_provider_command_model, "command_model")._refresh_cmd_panel()

func _refresh_metrics() -> void:
	_require(_provider_hud_layout, "hud_layout")._refresh_metrics()

func _sheet(p: String) -> Texture2D:
	return _require(_provider_unit_visuals, "unit_visuals")._sheet(p)

func unit_nodes(u: Dictionary) -> Dictionary:
	return _require(_provider_unit_visuals, "unit_visuals").unit_nodes(u)

func zoom_x() -> float:
	return _require(_provider_camera_controller, "camera_controller").zoom_x()

const CONTRACTS := {"camera_controller": ["zoom_x"], "command_model": ["_refresh_cmd_panel"], "hud_layout": ["_layout_status_labels", "_refresh_metrics"], "unit_visuals": ["_sheet", "unit_nodes"]}
var _provider_camera_controller: WeakRef
var _provider_command_model: WeakRef
var _provider_hud_layout: WeakRef
var _provider_unit_visuals: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.has("camera_controller") else null
	_provider_command_model = weakref(services["command_model"]) if services.has("command_model") else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.has("hud_layout") else null
	_provider_unit_visuals = weakref(services["unit_visuals"]) if services.has("unit_visuals") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_model = null
	_provider_hud_layout = null
	_provider_unit_visuals = null
