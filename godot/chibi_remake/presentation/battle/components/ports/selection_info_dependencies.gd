extends "res://named_port.gd"
## Explicit sibling capabilities for selection_info.

func _layout_status_labels(vp: Vector2, s: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._layout_status_labels(vp, s)

func _refresh_cmd_panel() -> void:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return
	provider._refresh_cmd_panel()

func _refresh_metrics() -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._refresh_metrics()

func _sheet(p: String) -> Texture2D:
	var provider = _require(_provider_unit_visuals, "unit_visuals")
	if provider == null: return null
	return provider._sheet(p)

func unit_nodes(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_unit_visuals, "unit_visuals")
	if provider == null: return {}
	return provider.unit_nodes(u)

func zoom_x() -> float:
	var provider = _require(_provider_camera_controller, "camera_controller")
	if provider == null: return 0.0
	return provider.zoom_x()

const CONTRACTS := {"camera_controller": ["zoom_x"], "command_model": ["_refresh_cmd_panel"], "hud_layout": ["_layout_status_labels", "_refresh_metrics"], "unit_visuals": ["_sheet", "unit_nodes"]}
var _provider_camera_controller: WeakRef
var _provider_command_model: WeakRef
var _provider_hud_layout: WeakRef
var _provider_unit_visuals: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_camera_controller = weakref(services["camera_controller"]) if services.get("camera_controller") != null else null
	_provider_command_model = weakref(services["command_model"]) if services.get("command_model") != null else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.get("hud_layout") != null else null
	_provider_unit_visuals = weakref(services["unit_visuals"]) if services.get("unit_visuals") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_camera_controller = null
	_provider_command_model = null
	_provider_hud_layout = null
	_provider_unit_visuals = null
