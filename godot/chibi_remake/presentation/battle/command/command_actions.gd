extends Object
## command actions: presentation component.
const UIState = preload("res://presentation/battle/view/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var _dep_command_art: Object
var _dep_command_model: Object
var _dep_selection_info: Object
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _order_stop(_hold: bool) -> void:
	_ui.host.actions.submit_command("stop")

func _act_build(idx: int) -> void:
	var bts: Array = _ui.host.queries.build_options()
	if idx < 0 or idx >= bts.size():
		return
	_ui.host.actions.begin_target("build", int(bts[idx].unit))
	# 已进入"点空地"状态 → 关掉建造清单，回到图标面板（下一步是地图点击）
	if _ui.host.queries.cmd_pending_kind() == "build":
		_ui.build_menu = false
		_dep_command_model._refresh_cmd_panel()

func _act_cancel_site(site: Dictionary) -> void:
	_ui.host.actions.cancel_work("site",int(site.uid),int(site.get("world_id",-1)))
	_dep_command_model._refresh_cmd_panel()

func _act_cancel_train(building: Dictionary) -> void:
	_ui.host.actions.cancel_work("training",int(building.uid),int(building.get("world_id",-1)))
	_dep_command_model._refresh_cmd_panel()

func _act_train(i: int) -> void:
	var b: Dictionary = _dep_selection_info._selected_building()
	var tts: Array = _ui.host.queries.train_types_for(int(b.unit)) if not b.is_empty() else []
	if i < 0 or i >= tts.size():
		return
	_ui.host.actions.submit_command("train", -1, int(tts[i].unit))

func _act_research(idx: int) -> void:
	_ui.host.actions.submit_command("research", -1, idx)
	_dep_command_model._refresh_cmd_panel()

func _act_cancel_research() -> void:
	_ui.host.actions.submit_command("cancel_research")
	_dep_command_model._refresh_cmd_panel()

func _act_group(n: int) -> void:
	_ui.host.actions.focus_group(n)

func _act_move() -> void:
	_ui.host.actions.begin_target("move")

func _act_attack() -> void:
	_ui.host.actions.begin_target("attack")

func _act_transport() -> void:
	_ui.host.actions.begin_target("transport")

func _act_repair() -> void:
	_ui.host.actions.begin_target("repair")

func _act_board() -> void:
	_ui.host.actions.begin_target("board")

func _act_watch() -> void:
	_ui.host.actions.submit_command("watch")

func _act_rest() -> void:
	_ui.host.actions.submit_command("rest")

func _act_disband() -> void:
	_ui.host.actions.submit_command("disband")

func _act_duel() -> void:
	_ui.host.actions.begin_target("duel")

func _act_form_menu() -> void:
	_ui.art_sub = "" if _ui.art_sub == "form" else "form"
	_dep_command_art._refresh_cmd_art()

func _act_hot_menu() -> void:
	_ui.art_sub = "" if _ui.art_sub == "hot" else "hot"
	_dep_command_art._refresh_cmd_art()

func _on_cmd(i: int) -> void:
	if i < 0 or i >= _ui.cmd_actions.size():
		return
	var c: Callable = _ui.cmd_actions[i]
	if c.is_valid():
		c.call()

func _on_hotkey(i: int) -> void:
	if i < 0 or i >= _ui.hot_actions.size():
		return
	var c: Callable = _ui.hot_actions[i]
	if c.is_valid():
		c.call()

func bind_dependencies(components: Object) -> void:
	_dep_command_art = components.command_art
	_dep_command_model = components.command_model
	_dep_selection_info = components.selection_info
