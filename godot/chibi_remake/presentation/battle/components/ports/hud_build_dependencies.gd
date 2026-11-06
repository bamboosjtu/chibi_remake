extends "res://named_port.gd"
## Explicit sibling capabilities for hud_build.

func _act_close_officer_pick() -> void:
	_require(_provider_selection_info, "selection_info")._act_close_officer_pick()

func _apply_metrics() -> void:
	_require(_provider_hud_layout, "hud_layout")._apply_metrics()

func _draw_ornament() -> void:
	_require(_provider_hud_layout, "hud_layout")._draw_ornament()

func _hud_click_hook(idx: int, hot: bool) -> void:
	_require(_provider_hud_input, "hud_input")._hud_click_hook(idx, hot)

func _hud_select_hook(want_building: bool) -> void:
	_require(_provider_hud_input, "hud_input")._hud_select_hook(want_building)

func _intro_finished() -> void:
	_require(_provider_controller, "controller")._intro_finished()

func _on_cmd(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._on_cmd(i)

func _on_cmd_page(dir: int) -> bool:
	return _require(_provider_command_model, "command_model")._on_cmd_page(dir)

func _on_hotkey(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._on_hotkey(i)

func _res_icon_path(kind: String) -> String:
	return _require(_provider_controller, "controller")._res_icon_path(kind)

const CONTRACTS := {"command_actions": ["_on_cmd", "_on_hotkey"], "command_model": ["_on_cmd_page"], "controller": ["_intro_finished", "_res_icon_path"], "hud_input": ["_hud_click_hook", "_hud_select_hook"], "hud_layout": ["_apply_metrics", "_draw_ornament"], "selection_info": ["_act_close_officer_pick"]}
var _provider_command_actions: WeakRef
var _provider_command_model: WeakRef
var _provider_controller: WeakRef
var _provider_hud_input: WeakRef
var _provider_hud_layout: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_actions = weakref(services["command_actions"]) if services.has("command_actions") else null
	_provider_command_model = weakref(services["command_model"]) if services.has("command_model") else null
	_provider_controller = weakref(services["controller"]) if services.has("controller") else null
	_provider_hud_input = weakref(services["hud_input"]) if services.has("hud_input") else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.has("hud_layout") else null
	_provider_selection_info = weakref(services["selection_info"]) if services.has("selection_info") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_actions = null
	_provider_command_model = null
	_provider_controller = null
	_provider_hud_input = null
	_provider_hud_layout = null
	_provider_selection_info = null
