extends SceneTree
var done := false
var b: Node2D
var game: Node

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func snapshot() -> Dictionary:
	if not game.save_game(b.units, b.commands._resources(), b.commands._save_extra()): return {}
	return game.load_save()

func find_unit(uid: int) -> Dictionary:
	for u in b.units:
		if int(u.uid) == uid: return u
	return {}

func world_text() -> String:
	var data := snapshot(); data.erase("savedAt"); data.erase("checksum")
	return JSON.stringify(data)

func run() -> void:
	game = root.get_node("Game"); game.current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for u in b.units: b.commands._cancel_unit_command(u); u.hold = true
	var hq: Dictionary = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) in [0,1])[0]
	var oc: Vector2i = b.nav.near_walkable(b.nav.cell_of_px(hq.ax + b.tile_w * 3.0, hq.ay))
	var op: Vector2 = b.nav.anchor_of(oc.x, oc.y)
	assert(b.commands._spawn_unit(10, b.player_owner, op.x, op.y, true))
	var own: Dictionary = b.units.back()
	assert(b.commands._spawn_unit(10, 3, op.x + 200.0, op.y, true))
	var enemy: Dictionary = b.units.back()
	var workers: Array = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 30).slice(0,3)
	var ids := workers.map(func(w): return int(w.uid))
	var own_uid: int = own.uid; var enemy_uid: int = enemy.uid
	var pool: Dictionary = b.economy.balance(3); pool.food = 450; b.economy.write(3, pool)
	var initial_food: float = b.food
	var eep: Vector2 = b.commands._edge_point(enemy, Vector2(hq.ax, hq.ay))
	var edge_cells: Array = b.commands._edge_neighbors(enemy)
	for i in range(workers.size()):
		var cell: Vector2i = edge_cells[mini(i, edge_cells.size() - 1)]
		var p: Vector2 = b.nav.anchor_of(cell.x, cell.y)
		var worker = workers[i]
		worker.ax = p.x; worker.ay = p.y
		b.commands._begin_gather(worker, enemy, [])
		for tick in range(99): b.commands._step_unit(worker, b.SIM_DT)
	assert(workers.all(func(w): return w.carry == 0 and w.gather_ticks == 99))
	var pending := snapshot(); assert(b.saver.apply_snapshot(pending))
	workers = ids.map(func(uid): return find_unit(uid)); enemy = find_unit(enemy_uid); own = find_unit(own_uid)
	for worker in workers: b.commands._step_unit(worker, b.SIM_DT)
	assert(workers[0].carry == 200 and workers[1].carry == 200 and workers[2].carry == 50)
	assert(b.economy.balance(3).food == 0 and b.food == initial_food, "loading transfers enemy pool into cargo only")
	var loaded := snapshot(); assert(b.saver.apply_snapshot(loaded))
	workers = ids.map(func(uid): return find_unit(uid)); own = find_unit(own_uid)
	var oep: Vector2 = b.commands._edge_point(own, Vector2(hq.ax, hq.ay), b.DEPOSIT_EDGE_PX)
	for worker in workers: worker.ax = oep.x; worker.ay = oep.y
	b.food = b.commands._food_capacity(b.player_owner) - 100
	assert(not b.commands._deposit_carry(workers[0]) and workers[0].carry == 200)
	assert(not b.commands._deposit_carry(workers[1]) and workers[1].carry == 200)
	assert(b.commands._deposit_carry(workers[2]) and workers[2].carry == 0)
	assert(b.food == b.commands._food_capacity(b.player_owner) - 50 and not b.commands._deposit_carry(workers[2]))
	b.food -= 350
	for worker in workers.slice(0,2): assert(b.commands._deposit_carry(worker))
	assert(b.food == b.commands._food_capacity(b.player_owner) and b.economy.balance(3).food == 0)
	assert(workers.all(func(w): return w.carry == 0 and not b.commands._deposit_carry(w)))
	assert(b.commands._spawn_unit(10,3,own.ax+44,own.ay,true))
	var another: Dictionary=b.units.back()
	assert((not find_unit(enemy_uid).alive or find_unit(enemy_uid).die_t>=0) and find_unit(enemy_uid).hp==0)
	pool=b.economy.balance(3);pool.food=200;b.economy.write(3,pool)
	for w in workers:
		assert(not b.harvesting.next_target(w,{"unit":10,"ax":another.ax,"ay":another.ay}))
		assert(w.state=="idle" and w.gather_obj==null and w.carry==0)
	assert(b.economy.balance(3).food==200,"exhausted granary must not redirect workers to another granary")
	b.selected = workers
	assert(b.commands._order_gather(own) == 0, "own granary is delivery only")
	print("ECONOMY TRANSFER PASS enemy pool450 -> cargo200-200-50 -> own stock / partial load save / full cap / no duplicate")
	print("ECONOMY GRANARY PASS exhausted source destroyed / cargo retained / no automatic robbery retarget")
	# 修理精确支付门槛、单次结算、满血封顶和失效目标保护。
	var worker: Dictionary = workers[0]
	var victim: Dictionary = workers[1]
	worker.group_officer = -1 # 单工人边界；组内派令另由 worker_groups 验证。
	worker.ax = victim.ax; worker.ay = victim.ay
	b.selected = [worker]
	for scarce in ["gold","wood","food","stone"]:
		var balance := {"gold":16.0,"wood":16.0,"food":16.0,"stone":16.0}; balance[scarce] = 15.0
		b.economy.write(b.player_owner, balance)
		victim.hp = victim.maxhp - 20
		assert(b.commands._order_repair(victim) == 1)
		for tick in range(11): b.commands._step_unit(worker, b.SIM_DT)
		assert(victim.hp == victim.maxhp - 20 and b.commands._resources() == balance and worker.state == "idle", str([scarce,victim.hp,victim.maxhp,b.commands._resources(),balance,worker.state]))
	b.economy.write(b.player_owner, {"gold":16,"wood":16,"food":16,"stone":16})
	victim.hp = victim.maxhp - 5
	assert(b.commands._order_repair(victim) == 1)
	for tick in range(11): b.commands._step_unit(worker, b.SIM_DT)
	assert(victim.hp == victim.maxhp and b.commands._resources() == {"gold":0.0,"wood":0.0,"food":0.0,"stone":0.0})
	b.economy.write(b.player_owner, {"gold":100,"wood":100,"food":100,"stone":100})
	victim.hp -= 20
	assert(b.commands._order_repair(victim) == 1)
	b.commands._kill(victim, {}) # 接令后死亡，但 alive 要等淡出结束才清。
	var paid: Dictionary = b.commands._resources()
	var hp: float = victim.hp
	b.commands._step_unit(worker, b.SIM_DT)
	assert(worker.state == "idle" and worker.repair_target == null and victim.hp == hp and b.commands._resources() == paid)
	assert(b.commands._order_repair(victim) == 0)
	b.commands._do_repair(worker, victim)
	assert(victim.hp == hp and b.commands._resources() == paid)
	print("ECONOMY REPAIR PASS each resource15 rejects / exact16 pays / capped one repair / dying target no charge")
	# 损坏经济数据必须在清空实体前拒绝，选择、货物和全世界逐字段不变。
	var good := snapshot(); b.selected = [worker]
	var before := world_text()
	var cases: Array = []
	for value in [-1,"100",NAN,INF]:
		var invalid: Dictionary = good.duplicate(true); invalid.resources.food = value; cases.append(invalid)
		invalid = good.duplicate(true); invalid.simulation.aiResources["3"].food = value; cases.append(invalid)
	for field in ["simulation","resources"]:
		var invalid: Dictionary = good.duplicate(true); invalid[field] = "broken"; cases.append(invalid)
	for value in [-1,NAN,0.5]:
		var invalid: Dictionary = good.duplicate(true); invalid.simulation.playerTech.bow = value; cases.append(invalid)
	for entry in [{"tech":23,"t":0},{"tech":3,"t":200},{"tech":3,"t":0.5},{"tech":3,"t":NAN},{"tech":3,"t":0,"cost":{"wood":-1}}]:
		var invalid: Dictionary = good.duplicate(true); invalid.simulation.techProgress = entry; cases.append(invalid)
	for entry in [{"buildingUid":NAN,"unit":30},{"buildingUid":own_uid,"unit":-1},{"buildingUid":own_uid,"unit":30,"owner":-1},{"buildingUid":int(worker.uid),"unit":30},{"buildingUid":own_uid,"unit":30,"t":0.5,"ticks":true}]:
		var invalid: Dictionary = good.duplicate(true); invalid.trainings = [entry]; cases.append(invalid)
	for invalid in cases:
		assert(not b.saver.apply_snapshot(invalid))
		assert(b.selected.size() == 1 and is_same(b.selected[0], worker) and world_text() == before)
	assert(b.saver.apply_snapshot(good))
	print("ECONOMY SNAPSHOT PASS corrupt player-AI funds / research cost-time-index / production owner-reference / atomic rejection / valid restore")
	b.free(); done = true; quit()
