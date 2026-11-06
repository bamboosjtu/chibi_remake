extends "res://named_port.gd"
## Explicit sibling capabilities for command_model.

func _act_assign_officer(idx: int) -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._act_assign_officer(idx)

func _act_attack() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_attack()

func _act_board() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_board()

func _act_build(idx: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_build(idx)

func _act_cancel_research() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_cancel_research()

func _act_cancel_site(site: Dictionary) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_cancel_site(site)

func _act_cancel_train(building: Dictionary) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_cancel_train(building)

func _act_disband() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_disband()

func _act_duel() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_duel()

func _act_form_menu() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_form_menu()

func _act_group(n: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_group(n)

func _act_hot_menu() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_hot_menu()

func _act_move() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_move()

func _act_repair() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_repair()

func _act_research(idx: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_research(idx)

func _act_rest() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_rest()

func _act_train(i: int) -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_train(i)

func _act_transport() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_transport()

func _act_watch() -> void:
	var provider = _require(_provider_command_actions, "command_actions")
	if provider == null: return
	provider._act_watch()

func _can_afford(tt: Dictionary) -> bool:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return false
	return provider._can_afford(tt)

func _cost_text(tt: Dictionary) -> String:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return ""
	return provider._cost_text(tt)

func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	var provider = _require(_provider_hud_build, "hud_build")
	if provider == null: return null
	return provider._mk_label(parent, size, col, align)

func _mobile_count(sel: Array) -> int:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return 0
	return provider._mobile_count(sel)

func _open_build_menu() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._open_build_menu()

func _place_left(c: Control, x: float, y: float, w: float, h: float) -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._place_left(c, x, y, w, h)

func _rebuild_stats_text() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._rebuild_stats_text()

func _refresh_banner() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._refresh_banner()

func _refresh_cmd_art() -> void:
	var provider = _require(_provider_command_art, "command_art")
	if provider == null: return
	provider._refresh_cmd_art()

func _refresh_metrics() -> void:
	var provider = _require(_provider_hud_layout, "hud_layout")
	if provider == null: return
	provider._refresh_metrics()

func _refresh_sel_frame() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._refresh_sel_frame()

func _refresh_troop() -> void:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return
	provider._refresh_troop()

func _selected_building() -> Dictionary:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return {}
	return provider._selected_building()

func _selected_site() -> Dictionary:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return {}
	return provider._selected_site()

func _worker_count(sel: Array) -> int:
	var provider = _require(_provider_selection_info, "selection_info")
	if provider == null: return 0
	return provider._worker_count(sel)

const CONTRACTS := {"command_actions": ["_act_attack", "_act_board", "_act_build", "_act_cancel_research", "_act_cancel_site", "_act_cancel_train", "_act_disband", "_act_duel", "_act_form_menu", "_act_group", "_act_hot_menu", "_act_move", "_act_repair", "_act_research", "_act_rest", "_act_train", "_act_transport", "_act_watch"], "command_art": ["_open_build_menu", "_refresh_cmd_art"], "hud_build": ["_mk_label"], "hud_layout": ["_place_left", "_refresh_metrics"], "selection_info": ["_act_assign_officer", "_can_afford", "_cost_text", "_mobile_count", "_rebuild_stats_text", "_refresh_banner", "_refresh_sel_frame", "_refresh_troop", "_selected_building", "_selected_site", "_worker_count"]}
var _provider_command_actions: WeakRef
var _provider_command_art: WeakRef
var _provider_hud_build: WeakRef
var _provider_hud_layout: WeakRef
var _provider_selection_info: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_actions = weakref(services["command_actions"]) if services.get("command_actions") != null else null
	_provider_command_art = weakref(services["command_art"]) if services.get("command_art") != null else null
	_provider_hud_build = weakref(services["hud_build"]) if services.get("hud_build") != null else null
	_provider_hud_layout = weakref(services["hud_layout"]) if services.get("hud_layout") != null else null
	_provider_selection_info = weakref(services["selection_info"]) if services.get("selection_info") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_actions = null
	_provider_command_art = null
	_provider_hud_build = null
	_provider_hud_layout = null
	_provider_selection_info = null
