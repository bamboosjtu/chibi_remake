extends SceneTree
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Contract = preload("res://simulation/definitions/contracts/constant_contract.gd")
const Identity = preload("res://app/saves/rules_identity.gd")
var done := false

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var config: Dictionary = preload("res://simulation/definitions/rule_catalog.gd").get_catalog("balance.json")
	assert(config.is_read_only() and Balance.harvest().is_read_only() and Contract.balance(config))
	assert(Identity.current() == "f479fd7967955c4d38a7cb4300100e8d508e7bdbb33214c0d8c187abcd8a006d")
	var altered := config.duplicate(true)
	altered.harvest.periodTicks = int(altered.harvest.periodTicks) + 1
	assert(Contract.balance(altered) and Identity.rule_projection("balance.json", altered).has("harvest"))
	altered.harvest.extractAmount = float(altered.harvest.carryCapacity) + 1
	assert(not Contract.balance(altered))
	var fine := _play(game, 0, 0.2)
	var batched := _play(game, 3, 3.0)
	assert(fine == batched, "Equivalent command ticks diverged across frame batching or speed")
	done = true
	print("COMMAND DETERMINISM PASS input / captured actor and resource / stale target / paused save / fixed ticks / v9 harvest continuation / frozen rules")
	quit()

func _play(game: Node, speed: int, ticks_per_frame: float) -> Array:
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.ai = null
	battle.clock.set_speed(speed)
	var worker: Dictionary = battle.units.filter(func(unit): return int(unit.owner) == battle.player_owner and int(unit.unit) == 30)[0]
	var origin := Vector2(worker.ax, worker.ay)
	var targets: Array = battle.decor_targets.filter(func(item): return int(item.phase) == 0)
	targets.sort_custom(func(a, b): return origin.distance_squared_to(Vector2(a.ax, a.ay)) < origin.distance_squared_to(Vector2(b.ax, b.ay)))
	var target: Dictionary = targets[0]
	var point := Vector2(target.ax, float(target.ay) - 30)
	battle.selected = [battle.selected[0]]
	var commander_uid := int(battle.selected[0].uid)
	var results := []
	battle.player_commands.command_finished.connect(func(command, result): results.append([int(command.tick), result]))
	assert(battle.actions.submit_point_order(point, true) > 0)
	var admitted: Dictionary = battle.player_commands.pending_commands()[0]
	assert(admitted.kind == "gather" and admitted.cell == target.cell and admitted.tick == 1)
	assert(JSON.parse_string(JSON.stringify(admitted)).kind == "gather")
	battle.selected = []
	var lease: int = game.pauses.acquire(battle, "fixture pause")
	assert(not battle.session_actions.save_game(18) and game.last_save_error.code == ERR_BUSY)
	game.pauses.release(lease)
	_advance(battle, 1, ticks_per_frame)
	assert(worker.state == "gather" and battle.selected.is_empty() and results == [[1, "applied"]])
	_advance(battle, 31, ticks_per_frame)
	assert(battle.session_actions.save_game(18))
	assert(battle.session_actions.load_slot(18).ok)
	var restored: Dictionary = battle.units.filter(func(unit): return int(unit.uid) == int(worker.uid))[0]
	assert(restored.gather_obj is Dictionary and restored.state in ["gather", "deliver"])
	battle.selected = battle.units.filter(func(unit): return int(unit.uid) == commander_uid)
	target = battle.decor_cells[targets[1].cell]
	point = Vector2(target.ax, float(target.ay) - 30)
	battle.player_commands.command_finished.connect(func(command, result): results.append([int(command.tick), result]))
	assert(battle.actions.submit_point_order(point, true) == 1)
	assert(battle.player_commands.pending_commands()[0].cell == target.cell)
	battle.world.harvest_orders._remove_decor(target)
	_advance(battle, 32, ticks_per_frame)
	assert(results.back() == [32, "stale_target"], str(results))
	_advance(battle, 50, ticks_per_frame)
	var payload: Dictionary = battle.saver.continuation_snapshot(game)
	payload.simulation.erase("speedIndex")
	var checksum: String = game.save_checksum(payload)
	battle.free()
	return [results, checksum]

func _advance(battle: Node2D, tick: int, ticks_per_frame: float) -> void:
	var period: float = battle.clock.period()
	while int(battle.sim_tick) < tick:
		var remaining := period * float(tick - int(battle.sim_tick)) - float(battle.sim_acc)
		battle.scene_controller._process(minf(period * ticks_per_frame, remaining + 0.0000000001))
	assert(int(battle.sim_tick) == tick)
