extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var pauses: Node = root.get_node("Game").pauses
	var first := Node.new(); var second := Node.new(); root.add_child(first); root.add_child(second)
	var a: int = pauses.acquire(first,"first")
	var b: int = pauses.acquire(second,"second")
	assert(paused and pauses.count() == 2 and pauses.is_top(b) and not pauses.is_top(a))
	pauses.release(a); pauses.release(a)
	assert(paused and pauses.count() == 1)
	second.free(); assert(not paused and pauses.count() == 0)
	for repeat in range(50):
		var token: int = pauses.acquire(first,"repeat"); pauses.release(token)
	assert(first.get_signal_connection_list("tree_exiting").is_empty(),"Closing a lease must remove its owner callback")
	var shared: int = pauses.acquire(first, "outer operation")
	pauses.acquire(first, "first inner operation")
	pauses.acquire(first, "second inner operation")
	assert(pauses.count() == 3 and first.get_signal_connection_list("tree_exiting").size() == 1)
	pauses.release(shared)
	assert(pauses.count() == 2 and first.get_signal_connection_list("tree_exiting").size() == 1)
	first.free()
	assert(not paused and pauses.count() == 0, "Owner exit releases all remaining leases")
	if not "--pause-unit-only" in OS.get_cmdline_user_args():
		_modals(pauses)
		print("PAUSE MODALS PASS nesting / media cancellation / world rollback and exchange / old scene disposal")
	print("PAUSE OWNERSHIP PASS independent leases / out-of-order close / owner release / no callback accumulation")
	quit()

func _modals(pauses: Node) -> void:
	var game: Node = root.get_node("Game"); game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	battle.view.event_view.restore_history()
	var scene_token: int = pauses.acquire(battle,"scene owner fixture")
	pauses.release(scene_token)
	var menu: CanvasLayer = battle.view.battle_menu
	var briefing: CanvasLayer = battle.view.briefing
	menu.open(); briefing.open()
	assert(paused and pauses.count() == 2)
	menu.close(); assert(paused and briefing.is_open)
	briefing.close(); assert(not paused)
	menu.open(); briefing.open(); briefing.close()
	assert(paused and menu.is_open and pauses.count() == 1)
	battle.view.event_view.restore_history()
	assert(paused,"Resetting media does not resume another modal's battle")
	var media: CanvasLayer = battle.view.event_view
	media.pause_token = pauses.acquire(media,"media fixture")
	media.active = true; media._finish_media()
	assert(paused and pauses.count() == 1)
	briefing.open()
	var snapshot: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	var world: WeakRef = weakref(battle.world)
	var transaction = load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure_after_attach = true
	assert(not battle.saver.apply_snapshot(snapshot)); transaction.force_view_failure_after_attach = false
	assert(paused and pauses.count() == 2 and is_same(world.get_ref(),battle.world))
	assert(battle.saver.apply_snapshot(snapshot))
	assert(paused and pauses.count() == 2 and world.get_ref() == null)
	menu.close(); assert(paused)
	briefing.close(); assert(not paused)
	menu.open(); briefing.open()
	battle.scene.ready_to_save = false; battle.free()
	assert(not paused and pauses.count() == 0)
