extends RefCounted
## command actions: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/command_actions_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _order_stop(_hold: bool) -> void:
	_ui.host.commands.military.stop_selected()

func _act_build(idx: int) -> void:
	var bts: Array = _ui.host.build_types
	if idx < 0 or idx >= bts.size():
		return
	_ui.host.commands.economy._start_build(bts[idx])
	# 已进入"点空地"状态 → 关掉建造清单，回到图标面板（下一步是地图点击）
	if _ui.host.commands.orders.cmd_pending_kind() == "build":
		_ui.build_menu = false
		ports._refresh_cmd_panel()

func _act_cancel_site(site: Dictionary) -> void:
	_ui.host.player_commands.submit(22,_ui.host.commands.economy._cancel_site.bind(site),Vector2.ZERO,int(site.uid))
	ports._refresh_cmd_panel()

func _act_cancel_train(building: Dictionary) -> void:
	_ui.host.player_commands.submit(23,_ui.host.commands.economy._cancel_training.bind(building),Vector2.ZERO,int(building.uid))
	ports._refresh_cmd_panel()

func _act_train(i: int) -> void:
	var b: Dictionary = ports._selected_building()
	var tts: Array = _ui.host.commands.economy.train_types_for(int(b.unit)) if not b.is_empty() else []
	if i < 0 or i >= tts.size():
		return
	_ui.host.player_commands.submit(16,_ui.host.commands.economy._start_train.bind(tts[i]),Vector2.ZERO,-1,int(tts[i].unit))

func _act_research(idx: int) -> void:
	_ui.host.player_commands.submit(17,_ui.host.commands.technology._start_tech.bind(idx),Vector2.ZERO,-1,idx)
	ports._refresh_cmd_panel()

func _act_cancel_research() -> void:
	_ui.host.player_commands.submit(24,_ui.host.commands.technology._cancel_tech)
	ports._refresh_cmd_panel()

func _act_group(n: int) -> void:
	_ui.host.commands.session.focus_group(n)

func _act_move() -> void:
	_ui.host.commands.military._cmd_begin("move")

func _act_attack() -> void:
	_ui.host.commands.military._cmd_begin("attack")

func _act_transport() -> void:
	_ui.host.commands.military._cmd_begin("transport")

func _act_repair() -> void:
	_ui.host.commands.military._cmd_begin("repair")

func _act_board() -> void:
	_ui.host.commands.military._cmd_begin("board")

func _act_watch() -> void:
	_ui.host.player_commands.submit(3,_ui.host.commands.military._cmd_watch)

func _act_rest() -> void:
	_ui.host.player_commands.submit(4,_ui.host.commands.military._cmd_rest)

func _act_disband() -> void:
	_ui.host.player_commands.submit(6,_ui.host.commands.military._cmd_disband)

func _act_duel() -> void:
	_ui.host.commands.military._duel_begin()

func _act_form_menu() -> void:
	_ui.art_sub = "" if _ui.art_sub == "form" else "form"
	ports._refresh_cmd_art()

func _act_hot_menu() -> void:
	_ui.art_sub = "" if _ui.art_sub == "hot" else "hot"
	ports._refresh_cmd_art()

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
