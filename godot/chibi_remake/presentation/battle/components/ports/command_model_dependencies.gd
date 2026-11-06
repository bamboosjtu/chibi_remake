extends "res://named_port.gd"
## Explicit sibling capabilities for command_model.

func _act_assign_officer(idx: int) -> void:
	_require(_provider_selection_info, "selection_info")._act_assign_officer(idx)

func _act_attack() -> void:
	_require(_provider_command_actions, "command_actions")._act_attack()

func _act_board() -> void:
	_require(_provider_command_actions, "command_actions")._act_board()

func _act_build(idx: int) -> void:
	_require(_provider_command_actions, "command_actions")._act_build(idx)

func _act_cancel_research() -> void:
	_require(_provider_command_actions, "command_actions")._act_cancel_research()

func _act_cancel_site(site: Dictionary) -> void:
	_require(_provider_command_actions, "command_actions")._act_cancel_site(site)

func _act_cancel_train(building: Dictionary) -> void:
	_require(_provider_command_actions, "command_actions")._act_cancel_train(building)

func _act_disband() -> void:
	_require(_provider_command_actions, "command_actions")._act_disband()

func _act_duel() -> void:
	_require(_provider_command_actions, "command_actions")._act_duel()

func _act_form_menu() -> void:
	_require(_provider_command_actions, "command_actions")._act_form_menu()

func _act_group(n: int) -> void:
	_require(_provider_command_actions, "command_actions")._act_group(n)

func _act_hot_menu() -> void:
	_require(_provider_command_actions, "command_actions")._act_hot_menu()

func _act_move() -> void:
	_require(_provider_command_actions, "command_actions")._act_move()

func _act_repair() -> void:
	_require(_provider_command_actions, "command_actions")._act_repair()

func _act_research(idx: int) -> void:
	_require(_provider_command_actions, "command_actions")._act_research(idx)

func _act_rest() -> void:
	_require(_provider_command_actions, "command_actions")._act_rest()

func _act_train(i: int) -> void:
	_require(_provider_command_actions, "command_actions")._act_train(i)

func _act_transport() -> void:
	_require(_provider_command_actions, "command_actions")._act_transport()

func _act_watch() -> void:
	_require(_provider_command_actions, "command_actions")._act_watch()

func _can_afford(tt: Dictionary) -> bool:
	return _require(_provider_selection_info, "selection_info")._can_afford(tt)

func _cost_text(tt: Dictionary) -> String:
	return _require(_provider_selection_info, "selection_info")._cost_text(tt)

func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	return _require(_provider_hud_build, "hud_build")._mk_label(parent, size, col, align)

func _mobile_count(sel: Array) -> int:
	return _require(_provider_selection_info, "selection_info")._mobile_count(sel)

func _open_build_menu() -> void:
	_require(_provider_command_art, "command_art")._open_build_menu()

func _place_left(c: Control, x: float, y: float, w: float, h: float) -> void:
	_require(_provider_hud_layout, "hud_layout")._place_left(c, x, y, w, h)

func _rebuild_stats_text() -> void:
	_require(_provider_selection_info, "selection_info")._rebuild_stats_text()

func _refresh_banner() -> void:
	_require(_provider_selection_info, "selection_info")._refresh_banner()

func _refresh_cmd_art() -> void:
	_require(_provider_command_art, "command_art")._refresh_cmd_art()

func _refresh_metrics() -> void:
	_require(_provider_hud_layout, "hud_layout")._refresh_metrics()

func _refresh_sel_frame() -> void:
	_require(_provider_selection_info, "selection_info")._refresh_sel_frame()

func _refresh_troop() -> void:
	_require(_provider_selection_info, "selection_info")._refresh_troop()

func _selected_building() -> Dictionary:
	return _require(_provider_selection_info, "selection_info")._selected_building()

func _selected_site() -> Dictionary:
	return _require(_provider_selection_info, "selection_info")._selected_site()

func _worker_count(sel: Array) -> int:
	return _require(_provider_selection_info, "selection_info")._worker_count(sel)

const CONTRACTS := {"command_actions": ["_act_attack", "_act_board", "_act_build", "_act_cancel_research", "_act_cancel_site", "_act_cancel_train", "_act_disband", "_act_duel", "_act_form_menu", "_act_group", "_act_hot_menu", "_act_move", "_act_repair", "_act_research", "_act_rest", "_act_train", "_act_transport", "_act_watch"], "command_art": ["_open_build_menu", "_refresh_cmd_art"], "hud_build": ["_mk_label"], "hud_layout": ["_place_left", "_refresh_metrics"], "selection_info": ["_act_assign_officer", "_can_afford", "_cost_text", "_mobile_count", "_rebuild_stats_text", "_refresh_banner", "_refresh_sel_frame", "_refresh_troop", "_selected_building", "_selected_site", "_worker_count"]}
var _provider_command_actions: WeakRef
var _provider_command_art: WeakRef
var _provider_hud_build: WeakRef
var _provider_hud_layout: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_actions = weakref(services["command_actions"]) if services.has("command_actions") else null
	_provider_command_art = weakref(services["command_art"]) if services.has("command_art") else null
	_provider_hud_build = weakref(services["hud_build"]) if services.has("hud_build") else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.has("hud_layout") else null
	_provider_selection_info = weakref(services["selection_info"]) if services.has("selection_info") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_actions = null
	_provider_command_art = null
	_provider_hud_build = null
	_provider_hud_layout = null
	_provider_selection_info = null
