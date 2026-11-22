extends RefCounted

var _battle: Node

func _init(battle: Node) -> void:
	_battle = battle

func set_sim_speed(index: int) -> bool:
	return _battle.world.battle_simulation.set_sim_speed(index)

func feedback(msg: String) -> void:
	_battle.world.effects.feedback(msg)

func handle_cheat_input(event: InputEvent) -> bool:
	return _battle.cheat_controller.handle_cheat_input(event)

func unhandled_input(event: InputEvent) -> void:
	_battle.scene_controller._unhandled_input(event)

func gather_at(resource: Dictionary, position: Vector2) -> void:
	_battle.world.player_commands.submit("gather", _battle.state.selected, position, int(resource.uid), -1, str(resource.get("cell", "")))

func allows_context(id: int) -> bool:
	return _battle.world.command_rules.allows_context(id)

func submit_command(kind: String, uid := -1, parameter := -1) -> int:
	if not _battle.scene.ready_to_save or _battle.get_tree().paused or _battle.session_actions.waiting_for_commands: return 0
	return _battle.world.player_commands.submit(kind, _battle.state.selected, Vector2.ZERO, uid, parameter)

func submit_point_order(position: Vector2, context: bool) -> int:
	if not _battle.scene.ready_to_save or _battle.get_tree().paused or _battle.session_actions.waiting_for_commands: return 0
	return _battle.world.world_orders.submit_point_order(position, context)

func begin_target(kind: String, parameter := -1) -> void:
	if not _battle.scene.ready_to_save or _battle.get_tree().paused or _battle.session_actions.waiting_for_commands: return
	match kind:
		"unload":
			_battle.world.world_orders._clear_pending()
			submit_command("unload")
		"jimou": _battle.world.abilities._jimou_begin(parameter)
		"duel": _battle.world.abilities._duel_begin()
		"build":
			for option in _battle.state.build_types:
				if int(option.unit) == parameter:
					_battle.world.construction_orders._start_build(option)
					break
		"move", "attack", "transport", "repair", "board", "join":
			_battle.world.command_groups._cmd_begin(kind)

func select_at(position: Vector2, add: bool) -> void:
	_battle.world.selection._select_click(position, add)
	_battle.scene_controller._view_hud()

func cancel_work(kind: String, uid: int, epoch: int) -> bool:
	if not is_instance_valid(_battle) or not _battle.is_inside_tree(): return false
	if epoch != _battle.world.get_instance_id() or kind not in ["site", "training"]: return false
	return submit_command("cancel_site" if kind == "site" else "cancel_train", uid) > 0

func focus_group(n: int) -> bool:
	if not _battle.world.command_groups._group_recall(n):
		return false
	if _battle.state.selected.is_empty():
		return true
	var leader: Dictionary = _battle.state.selected[0]
	if _battle.scene.cam != null:
		_battle.scene.cam.position = Vector2(float(leader.ax), float(leader.ay))
		if _battle.scene.view != null:
			_battle.scene.view.clamp_camera()
	_battle.scene_controller._view_hud()
	return true
