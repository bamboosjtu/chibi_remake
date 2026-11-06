extends "res://named_port.gd"
## Explicit sibling capabilities for command_art.

func _act_close_officer_pick() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._act_close_officer_pick()

func _act_disband() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_disband()

func _act_open_officer_pick() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._act_open_officer_pick()

func _act_rest() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_rest()

func _act_watch() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_watch()

func _mk_button(parent: Node, size: float) -> Button:
	var provider = _require(_provider_hud_build, "hud_build")
	if provider == null: return null
	return provider._mk_button(parent, size)

func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	var provider = _require(_provider_hud_build, "hud_build")
	if provider == null: return null
	return provider._mk_label(parent, size, col, align)

func _on_cmd(i: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._on_cmd(i)

func _on_cmd_page(dir: int) -> bool:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return false
	return provider._on_cmd_page(dir)

func _refresh_cmd_panel() -> void:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return
	provider._refresh_cmd_panel()

func panel_kind() -> String:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return ""
	return provider.panel_kind()

func update_panel() -> void:
	var provider = _require(_provider_command_model, "command_model")
	if provider == null: return
	provider.update_panel()

const CONTRACTS := {"command_actions": ["_act_disband", "_act_rest", "_act_watch", "_on_cmd"], "command_model": ["_on_cmd_page", "_refresh_cmd_panel", "panel_kind", "update_panel"], "hud_build": ["_mk_button", "_mk_label"], "selection_info": ["_act_close_officer_pick", "_act_open_officer_pick"]}
var _provider_command_actions: WeakRef
var _provider_command_model: WeakRef
var _provider_hud_build: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_actions = weakref(services["command_actions"]) if services.get("command_actions") != null else null
	_provider_command_model = weakref(services["command_model"]) if services.get("command_model") != null else null
	_provider_hud_build = weakref(services["hud_build"]) if services.get("hud_build") != null else null
	_provider_selection_info = weakref(services["selection_info"]) if services.get("selection_info") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_actions = null
	_provider_command_model = null
	_provider_hud_build = null
	_provider_selection_info = null
