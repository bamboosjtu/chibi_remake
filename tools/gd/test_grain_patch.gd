extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var b: Node2D = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for u in b.units: b.commands.military._cancel_unit_command(u); u.hold = true
	var workers: Array = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 30)
	var target: Dictionary = b.decor_cells["7_209"]
	var grain_patch: Array = b.commands.orders._resource_patch_cells(target)
	var grain_cells := {}
	for cell in grain_patch: grain_cells[cell] = true
	var approach: Dictionary = b.commands.orders._edge_interaction_choice(workers[0], target)
	assert(not approach.is_empty(), "dense grain click should route to a reachable outside edge")
	assert(_route_outside(b, approach.path, grain_cells, b.commands.world._unit_cell(workers[0])))
	assert(Vector2(workers[0].ax, workers[0].ay).distance_to(Vector2(target.ax,target.ay)) > float(workers[0].vision) * b.tile_w)
	b.selected = workers
	assert(b.commands.economy._order_gather(target) == workers.size())
	for worker in workers:
		assert(worker.state == "gather" and not worker.path.is_empty())
		assert(int(worker.gather_obj.unit) == 102)
		assert(_route_outside(b, worker.path, grain_cells, b.commands.world._unit_cell(worker)), "worker route enters grain")
	# Tree clusters use the same outside-edge rule as grain patches.
	var wood_choice: Dictionary = {}
	for tree in b.decor_targets:
		if int(tree.unit) not in [100, 101] or not bool(tree.alive): continue
		wood_choice = b.commands.orders._edge_interaction_choice(workers[0], tree)
		if not wood_choice.is_empty(): break
	assert(not wood_choice.is_empty(), "test map should expose a reachable tree patch")
	var wood_patch: Array = b.commands.orders._resource_patch_cells(wood_choice.object)
	var wood_cells := {}
	for cell in wood_patch: wood_cells[cell] = true
	assert(_route_outside(b, wood_choice.path, wood_cells, b.commands.world._unit_cell(workers[0])), "wood route enters tree patch")
	var initial: float = b.food
	var deliveries := {}; var cargo_seen := {}
	var saved_return := false
	var worker_ids: Array = workers.map(func(worker): return int(worker.uid))
	for worker in workers: deliveries[int(worker.uid)] = 0
	for tick in range(12000):
		for worker in workers:
			var before_carry: float = worker.carry
			b.commands.orders._step_unit(worker, b.SIM_DT)
			if float(worker.carry) > 0: cargo_seen[int(worker.uid)] = true
			if before_carry > 0 and float(worker.carry) == 0: deliveries[int(worker.uid)] += 1
			var standing_source: Dictionary = b.decor_cells.get("%d_%d" % [b.commands.world._unit_cell(worker).x, b.commands.world._unit_cell(worker).y], {})
			assert(standing_source.is_empty() or not bool(standing_source.alive), "worker stood inside a live resource cell")
		b.commands.world._update_gates()
		if not saved_return and workers.any(func(worker): return float(worker.carry) > 0.0):
			var game := root.get_node("Game")
			assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()), "save while a depleted resource is being returned")
			var snapshot: Dictionary = game.load_save()
			assert(snapshot.has("checksum") and game.verify_save_checksum(snapshot))
			assert(b.saver.apply_snapshot(snapshot), "harvest task must reload before continuing")
			workers = b.units.filter(func(worker): return int(worker.uid) in worker_ids)
			saved_return = true
		if deliveries.values().all(func(count): return int(count) >= 2): break
	assert(deliveries.values().all(func(count): return int(count) >= 2), "each worker must return to the assigned patch after delivery: %s" % deliveries)
	assert(cargo_seen.size() == 4 and b.food - initial >= 1600)
	print("GRAIN PATCH PASS interior click / connected reachable edge / four workers / at least two deliveries each=", deliveries, " food=", b.food-initial)
	b.free(); done = true; quit()

func _route_outside(battle: Node2D, path: Array, patch: Dictionary, start: Vector2i) -> bool:
	for point in path:
		var cell: Vector2i = battle.nav.cell_of_px(point.x, point.y)
		if patch.has(cell) and cell != start: return false
	return true
