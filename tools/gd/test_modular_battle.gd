extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.cli_mode = true
	var event_view: CanvasLayer = battle.view.event_view
	assert(event_view.host.has_method("is_battle_context") and event_view.host.is_battle_context(), "Event playback must recognize the battle capability")
	battle.task_events.append({"id": 6, "tick": battle.sim_tick})
	event_view._process(0)
	assert(event_view.cursor == battle.task_events.size(), "Battle event dispatch must advance its cursor")
	if FileAccess.file_exists("res://media/videos/EVENT6.AVI"):
		assert(event_view.active and paused, "Available chapter media must actually play")
	event_view.restore_history()
	var state_id: int = battle.state.get_instance_id()
	for unit in battle.units:
		for key in ["spr", "skin", "diamond", "hbar", "hfill", "gate_module"]:
			assert(not unit.has(key), "Simulation records must not own presentation nodes")
		assert(battle.view.unit_nodes(unit).has("spr"))
	assert(battle.commands.session._save_game())
	var snapshot: Dictionary = root.get_node("Game").load_save()
	var before: String = JSON.stringify(battle.commands.session._save_extra())
	var selection: Array = battle.selected.duplicate()
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.units[0].simulation.build_targetUid = 2147483646
	assert(not battle.saver.apply_snapshot(invalid))
	assert(JSON.stringify(battle.commands.session._save_extra()) == before and battle.selected == selection)
	assert(battle.saver.apply_snapshot(snapshot))
	assert(battle.state.get_instance_id() != state_id)
	for unit in battle.units:
		assert(not unit.has("spr") and battle.view.unit_nodes(unit).has("spr"))
	var state_ref: WeakRef = weakref(battle.state)
	var view_ref: WeakRef = weakref(battle.view._ui)
	battle.free()
	assert(state_ref.get_ref() == null and view_ref.get_ref() == null, "Composed services must not retain a closed battle")
	print("MODULAR BATTLE PASS node ownership / rejected snapshot atomicity / stable state / restored UID registry / lifecycle")
	quit()
