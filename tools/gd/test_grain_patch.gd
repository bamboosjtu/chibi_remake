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
	for u in b.units: b.world.command_groups._cancel_unit_command(u); u.hold = true
	var workers: Array = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 30)
	var target: Dictionary = b.decor_cells["7_209"]
	var grain_patch: Array = b.world.harvest_orders._resource_patch_cells(target)
	var grain_cells := {}
	for cell in grain_patch: grain_cells[cell] = true
	var approach: Dictionary = b.world.harvest_orders._harvest_interaction_choice(workers[0], target)
	assert(not approach.is_empty(), "dense grain click should route to a reachable outside edge")
	assert(_route_outside(b, approach.path, grain_cells, b.world.spatial_index._unit_cell(workers[0])))
	assert(Vector2(workers[0].ax, workers[0].ay).distance_to(Vector2(target.ax,target.ay)) > float(workers[0].vision) * b.tile_w)
	b.selected = workers
	assert(b.world.harvest_orders._order_gather(target) == workers.size())
	for worker in workers:
		assert(worker.state == "gather" and not worker.path.is_empty())
		assert(int(worker.gather_obj.unit) == 102)
		assert(_route_outside(b, worker.path, grain_cells, b.world.spatial_index._unit_cell(worker)), "worker route enters grain")
	# Tree clusters use the same outside-edge rule as grain patches.
	var wood_choice: Dictionary = {}
	for tree in b.decor_targets:
		if int(tree.unit) not in [100, 101] or not bool(tree.alive): continue
		wood_choice = b.world.harvest_orders._harvest_interaction_choice(workers[0], tree)
		if not wood_choice.is_empty(): break
	assert(not wood_choice.is_empty(), "test map should expose a reachable tree patch")
	var wood_patch: Array = b.world.harvest_orders._resource_patch_cells(wood_choice.object)
	var wood_cells := {}
	for cell in wood_patch: wood_cells[cell] = true
	assert(_route_outside(b, wood_choice.path, wood_cells, b.world.spatial_index._unit_cell(workers[0])), "wood route enters tree patch")
	var initial: float = b.food
	var deliveries := {}; var cargo_seen := {}
	var saved_return := false
	var worker_ids: Array = workers.map(func(worker): return int(worker.uid))
	for worker in workers: deliveries[int(worker.uid)] = 0
	for tick in range(12000):
		for worker in workers:
			var before_carry: float = worker.carry
			b.world.unit_actions._step_unit(worker, b.SIM_DT)
			if float(worker.carry) > 0: cargo_seen[int(worker.uid)] = true
			if before_carry > 0 and float(worker.carry) == 0: deliveries[int(worker.uid)] += 1
			var standing_source: Dictionary = b.decor_cells.get("%d_%d" % [b.world.spatial_index._unit_cell(worker).x, b.world.spatial_index._unit_cell(worker).y], {})
			assert(standing_source.is_empty() or not bool(standing_source.alive), "worker stood inside a live resource cell")
		b.world.battle_simulation._update_gates()
		if not saved_return and workers.any(func(worker): return float(worker.carry) > 0.0):
			var game := root.get_node("Game")
			assert(game.save_game(b.units,b.world.economy.player_resources(),b.scene_controller._save_extra()), "save while a depleted resource is being returned")
			var snapshot: Dictionary = game.load_save()
			assert(snapshot.has("checksum") and game.verify_save_checksum(snapshot))
			assert(b.saver.apply_snapshot(snapshot), "harvest task must reload before continuing")
			workers = b.units.filter(func(worker): return int(worker.uid) in worker_ids)
			saved_return = true
		if deliveries.values().all(func(count): return int(count) >= 2): break
	assert(deliveries.values().all(func(count): return int(count) >= 2), "each worker must return to the assigned patch after delivery: %s" % deliveries)
	assert(cargo_seen.size() == 4 and b.food - initial >= 1600)
	print("GRAIN PATCH PASS interior click / connected reachable edge / four workers / at least two deliveries each=", deliveries, " food=", b.food-initial)
	assert(_verify_disconnected_field(b, workers[0]))
	assert(_verify_wood_crew(b, workers))
	assert(_verify_wood_retry(b, workers[0]))
	b.free(); done = true; quit()

func _verify_disconnected_field(b: Node2D, worker: Dictionary) -> bool:
	var orders = b.world.harvest_orders
	var nav = b.nav
	var previous: Dictionary = b.decor_cells["17_237"]
	var nearby: Dictionary = b.decor_cells["16_232"]
	var patch: Array = orders._resource_patch_cells(previous)
	assert(not patch.is_empty() and not patch.has(nav.cell_of_px(nearby.ax, nearby.ay)))
	for cell in patch: orders._remove_decor(b.decor_cells["%d_%d" % [cell.x, cell.y]])
	for member in b.units:
		if int(member.unit) == 30: b.world.command_groups._cancel_unit_command(member)
	var hq: Dictionary = b.units.filter(func(u): return int(u.unit) == 0 and int(u.owner) == b.player_owner)[0]
	var edge: Vector2 = b.world.interaction_paths._edge_point(hq, Vector2(previous.ax, previous.ay), b.DEPOSIT_EDGE_PX)
	worker.ax = edge.x; worker.ay = edge.y
	worker.carry = 200.0; worker.carry_kind = "food"
	orders._begin_gather(worker, previous, [])
	b.world.spatial_index._rebuild_unit_index()
	var capacity: float = orders._food_capacity(b.player_owner)
	b.food = capacity - 100.0
	for tick in range(8): b.world.unit_actions._step_unit(worker, b.SIM_DT)
	assert(worker.state == "deliver" and worker.carry == 200 and is_same(worker.gather_obj, previous))
	b.food = capacity - 400.0
	for tick in range(45):
		b.world.unit_actions._step_unit(worker, b.SIM_DT)
		if worker.carry == 0: break
	assert(worker.state == "gather" and worker.carry == 0 and b.food == capacity - 200.0)
	var chosen: Dictionary = worker.gather_obj
	var chosen_at := Vector2(chosen.ax, chosen.ay)
	assert(chosen.alive and int(chosen.unit) == 102)
	assert(chosen_at.distance_to(edge) > float(worker.vision) * b.tile_w)
	assert(chosen_at.distance_to(Vector2(previous.ax, previous.ay)) <= float(worker.vision) * b.tile_w)
	for tick in range(1800):
		b.world.battle_simulation._update_gates()
		b.world.unit_actions._step_unit(worker, b.SIM_DT)
		if worker.carry > 0: break
	assert(worker.carry == 200 and worker.carry_kind == "food")
	print("LIU GRAIN RETARGET PASS depot full / retry / disconnected nearby field outside depot vision / next haul")
	return true

func _verify_wood_crew(b: Node2D, workers: Array) -> bool:
	var orders = b.world.harvest_orders
	for worker in workers:
		worker.carry = 0.0
		worker.carry_kind = ""
	b.selected = workers
	var tree: Dictionary = b.decor_cells["20_98"]
	assert(int(tree.unit) == 100 and orders._order_gather(tree) == workers.size())
	var deliveries := {}
	for tick in range(3600):
		b.world.battle_simulation._update_gates()
		for worker in workers:
			var was_carrying: bool = worker.carry > 0.0
			b.world.unit_actions._step_unit(worker, b.SIM_DT)
			if was_carrying and worker.carry == 0:
				deliveries[worker.uid] = int(deliveries.get(worker.uid, 0)) + 1
		if deliveries.size() == workers.size() and deliveries.values().min() >= 2: break
	assert(deliveries.size() == workers.size() and deliveries.values().min() >= 2, "Every worker must make two wood deliveries: %s" % deliveries)
	print("LIU WOOD CREW PASS four workers approach the forest and deliver twice")
	return true

func _verify_wood_retry(b: Node2D, worker: Dictionary) -> bool:
	var orders = b.world.harvest_orders
	var tree: Dictionary = b.decor_cells["9_71"]
	for member in b.units:
		if int(member.unit) == 30: b.world.command_groups._cancel_unit_command(member)
	assert(tree.alive and orders._resource_patch_cells(tree).size() == 1)
	assert(not orders._harvest_interaction_choice(worker, tree).is_empty())
	worker.carry = 0.0
	worker.carry_kind = ""
	orders._begin_gather(worker, tree, [])
	var approaches: Array = b.world.interaction_paths._edge_neighbors(tree)
	for cell in approaches: b.nav.block(cell)
	b.world.unit_actions._step_unit(worker, b.SIM_DT)
	assert(worker.state == "gather" and worker.path.is_empty() and worker.repath > 0.0)
	for cell in approaches: b.nav.unblock(cell)
	for tick in range(1800):
		b.world.battle_simulation._update_gates()
		b.world.unit_actions._step_unit(worker, b.SIM_DT)
		if worker.carry > 0.0: break
	assert(worker.carry == 200.0 and worker.carry_kind == "wood")
	print("LIU WOOD RETRY PASS temporarily blocked approach / retained order / extraction after reopening")
	return true

func _route_outside(battle: Node2D, path: Array, patch: Dictionary, start: Vector2i) -> bool:
	for point in path:
		var cell: Vector2i = battle.nav.cell_of_px(point.x, point.y)
		if patch.has(cell) and cell != start: return false
	return true
