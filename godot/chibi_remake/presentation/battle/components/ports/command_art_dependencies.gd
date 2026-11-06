extends "res://named_port.gd"
## Explicit sibling capabilities for command_art.

func _act_close_officer_pick() -> void:
	_require(_provider_selection_info, "selection_info")._act_close_officer_pick()

func _act_disband() -> void:
	_require(_provider_command_actions, "command_actions")._act_disband()

func _act_open_officer_pick() -> void:
	_require(_provider_selection_info, "selection_info")._act_open_officer_pick()

func _act_rest() -> void:
	_require(_provider_command_actions, "command_actions")._act_rest()

func _act_watch() -> void:
	_require(_provider_command_actions, "command_actions")._act_watch()

func _mk_button(parent: Node, size: float) -> Button:
	return _require(_provider_hud_build, "hud_build")._mk_button(parent, size)

func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	return _require(_provider_hud_build, "hud_build")._mk_label(parent, size, col, align)

func _on_cmd(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._on_cmd(i)

func _on_cmd_page(dir: int) -> bool:
	return _require(_provider_command_model, "command_model")._on_cmd_page(dir)

func _refresh_cmd_panel() -> void:
	_require(_provider_command_model, "command_model")._refresh_cmd_panel()

func panel_kind() -> String:
	return _require(_provider_command_model, "command_model").panel_kind()

func update_panel() -> void:
	_require(_provider_command_model, "command_model").update_panel()

const CONTRACTS := {"command_actions": ["_act_disband", "_act_rest", "_act_watch", "_on_cmd"], "command_model": ["_on_cmd_page", "_refresh_cmd_panel", "panel_kind", "update_panel"], "hud_build": ["_mk_button", "_mk_label"], "selection_info": ["_act_close_officer_pick", "_act_open_officer_pick"]}
var _provider_command_actions: WeakRef
var _provider_command_model: WeakRef
var _provider_hud_build: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_actions = weakref(services["command_actions"]) if services.has("command_actions") else null
	_provider_command_model = weakref(services["command_model"]) if services.has("command_model") else null
	_provider_hud_build = weakref(services["hud_build"]) if services.has("hud_build") else null
	_provider_selection_info = weakref(services["selection_info"]) if services.has("selection_info") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_actions = null
	_provider_command_model = null
	_provider_hud_build = null
	_provider_selection_info = null
