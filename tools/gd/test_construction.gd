extends SceneTree
var done := false
var b: Node2D

func _initialize() -> void:
	create_timer(75).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func find_unit(uid: int) -> Dictionary:
	for unit in b.units:
		if int(unit.uid) == uid: return unit
	return {}

func save() -> Dictionary:
	var game := root.get_node("Game")
	if not game.save_game(b.units, b.commands._resources(), b.commands._save_extra()): return {}
	return game.load_save()

func run() -> void:
	root.get_node("Game").current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for unit in b.units: b.commands._cancel_unit_command(unit); unit.hold = true
	var hq: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) in [0,1])[0]
	var site: Dictionary = b.commands._place_building(3, 11, Vector2(hq.ax + 300, hq.ay), true)
	assert(not site.is_empty())
	var independent: Dictionary = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 30)[0]
	var group: int = independent.group_officer
	independent.group_officer = -1; b.selected = [independent]
	var old_owner: int = site.owner
	site.owner = b.player_owner
	var resources: Dictionary = b.commands._resources().duplicate()
	assert(b.commands._order_repair(site) == 0 and not b.commands._do_repair(independent,site))
	assert(site.hp == 0 and b.commands._resources() == resources)
	print("CONSTRUCTION REPAIR PASS independent=0 hp=",site.hp)
	site.owner = old_owner; independent.group_officer = group
	for tick in range(400): b.commands._process_sites(b.SIM_DT)
	assert(site.alive and site.site and site.hp == 0, "AI site cannot grow without physical workers")
	var start: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) == 30)[0]
	assert(b.commands._spawn_unit(30, 3, start.ax, start.ay, true))
	var worker: Dictionary = b.units.back()
	var captain: Dictionary = b.units.filter(func(u): return int(u.owner) == 3 and not u.get("officer", {}).is_empty())[0]
	var captain_uid: int = captain.uid
	for member in b.units:
		if int(member.owner) == 3 and int(member.get("group_officer", -1)) == int(captain.officer.index): member.group_officer = -1
	worker.group_officer = int(captain.officer.index)
	worker.carry = 137; worker.carry_kind = "wood"
	worker.hold = true
	assert(b.commands._assign_build_worker(worker, site))
	var walked := 0
	while int(worker.get("site_inside_uid", -1)) != int(site.uid) and walked < 3000:
		b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT); walked += 1
		assert(site.hp == 0, "walking itself cannot add construction HP")
	assert(walked > 0 and walked < 3000)
	for tick in range(3): b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT)
	assert(site.hp == 0 and worker.build_t == 3)
	var worker_uid: int = worker.uid; var site_uid: int = site.uid
	var halfway := save(); assert(b.saver.apply_snapshot(halfway))
	worker = find_unit(worker_uid); site = find_unit(site_uid); captain = find_unit(captain_uid)
	assert(worker.build_target == site and worker.state == "build" and site.hp == 0)
	assert(worker.carry == 137 and worker.carry_kind == "wood")
	b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT)
	assert(site.hp == 2 and worker.build_t == 0)
	b.commands._cancel_unit_command(worker)
	worker.hold = true # 不把施工停止测试混入仍待确认的空闲索敌策略。
	for tick in range(80): b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT)
	assert(site.hp == 2)
	print("CONSTRUCTION PHYSICAL PASS AI site0 without workers / actual walk / fourth-tick2HP / save / leaving stops work")
	# 把真实寻路起点封成独立区域；工人在开工途中被阻断，不能用替代自动进度完成。
	worker.ax = start.ax; worker.ay = start.ay
	var cell: Vector2i = b.nav.cell_of_px(worker.ax, worker.ay)
	cell = b.commands._near_walkable(cell)
	var anchor: Vector2 = b.nav.anchor_of(cell.x, cell.y)
	worker.ax = anchor.x; worker.ay = anchor.y
	assert(b.commands._dist_to_obj(worker, site) > b.GATHER_REACH)
	var closed := []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var neighbor := Vector2i(cell.x + dx, cell.y + dy)
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= int(b.map_data.rows) or neighbor.y >= int(b.map_data.cols): continue
			if not b.nav.is_solid(neighbor): b.nav.block(neighbor); closed.append(neighbor)
	assert(not b.commands._assign_build_worker(worker, site))
	worker.state = "build"; worker.build_target = site; worker.path = []; worker.build_t = 3
	b.commands._step_unit(worker, b.SIM_DT)
	assert(site.hp == 2 and worker.state == "idle" and worker.build_target == null and worker.build_t == 0)
	for tick in range(40): b.commands._process_sites(b.SIM_DT)
	assert(site.hp == 2)
	for neighbor in closed: b.nav.unblock(neighbor)
	print("CONSTRUCTION BLOCKED PASS real sealed navigation / interrupted arrival / no automatic HP / cleared reference")
	# 施工期间工地归属变化、销毁、工人载船或移除均不得继续加HP。
	assert(b.commands._assign_build_worker(worker, site), str([b.commands._valid_build_worker(worker, site),worker.alive,worker.die_t,worker.owner,site.alive,site.die_t,site.owner,site.site,b.commands._dist_to_obj(worker,site)]))
	site.owner = b.player_owner
	b.commands._step_unit(worker, b.SIM_DT)
	assert(site.hp == 2 and worker.state != "build" and worker.build_target == null)
	assert(not b.commands._assign_build_worker(worker, site))
	site.owner = 3
	worker.attached = true
	assert(not b.commands._assign_build_worker(worker, site))
	worker.attached = false
	var soldier: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and b.commands._is_hero_unit(u))[0]
	soldier.owner = 3
	assert(not b.commands._assign_build_worker(soldier, site))
	assert(b.commands._assign_build_worker(worker, site))
	worker.hold = true
	b.commands._kill(site)
	for tick in range(8): b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT)
	assert(site.die_t >= 0 and site.hp == 2 and worker.state != "build" and worker.build_target == null)
	print("CONSTRUCTION VALIDITY PASS foreign / attached / non-worker / destroyed site rejected")
	# AI执行API要求决策层提供工人；拒绝缺工/敌方工人时不创建工地、不扣款。
	var base: Dictionary = b.commands._place_building(3, 11, Vector2(worker.ax, worker.ay), false)
	assert(not base.is_empty()) # 有真实基地作选址锚点，避免跨敌方城门的无关导航条件。
	var balance := {"gold":10000.0,"wood":10000.0,"food":10000.0,"stone":10000.0}
	b.economy.write(3, balance)
	var size: int = b.units.size()
	assert(not b.commands.ai_place_building(3, 5) and b.units.size() == size and b.economy.balance(3) == balance)
	var own_worker: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) == 30)[0]
	assert(not b.commands.ai_place_building(3, 5, own_worker) and b.units.size() == size and b.economy.balance(3) == balance)
	assert(b.commands.ai_place_building(3, 5, captain))
	var new_site: Dictionary = b.units.back()
	assert(new_site.site and new_site.hp == 0 and worker.state == "build" and worker.build_target == new_site)
	var cost: Dictionary = b.commands.ai_unit_cost(5)
	for kind in balance: assert(b.economy.balance(3)[kind] == balance[kind] - cost[kind])
	var paid: Dictionary = b.economy.balance(3).duplicate()
	b.commands._cancel_unit_command(worker)
	assert(b.commands._assign_build_worker(worker, new_site) and b.economy.balance(3) == paid, "resume is not a second purchase")
	print("CONSTRUCTION PAYMENT PASS worker-team commander required / reachable site / normal cost once / resuming no charge")
	# 真实AI计划执行：没有空闲队伍就等待；完工后同一武将队伍可承接下一处工地。
	b.ai = load("res://simulation/systems/ai.gd").new(b)
	b.ai._refresh_plan(3)
	var count: int = b.units.size()
	var waiting_cost: Dictionary = b.economy.balance(3).duplicate()
	b.ai._build_step(3)
	assert(b.units.size() == count and b.economy.balance(3) == waiting_cost)
	new_site.hp = new_site.maxhp - 2
	for tick in range(3000):
		b.commands._step_unit(worker, b.SIM_DT); b.commands._process_sites(b.SIM_DT)
		if not new_site.site: break
	assert(not new_site.site and worker.state != "build")
	worker.state = "idle"; worker.hold = true
	b.ai._build_step(3)
	var planned_site: Dictionary = b.units.back()
	assert(b.units.size() == count + 1 and planned_site.site and planned_site.hp == 0)
	assert(worker.build_target == planned_site and worker.state == "build" and captain.hold and (captain.state == "idle" or int(captain.site_follow_uid) == int(planned_site.uid)))
	assert(int(b.ai.plan[3]) == 0)
	var planned_kind := int(planned_site.unit) - int(planned_site.unit) % 2
	b.ai._refresh_plan(3)
	var item := int(b.ai.plan.get(3,0))
	if item > 0:
		var target_type := int(b.ai.PLAN_TO_BUILDING[item])
		assert(target_type - target_type % 2 != planned_kind, "unfinished site reserves plan without granting unlocks")
	b.commands.ai_order_rally(3); b.commands.ai_order_intercept(3, captain, 90); b.commands.ai_order_assault(3)
	assert(worker.state == "build" and worker.build_target == planned_site and (captain.state == "idle" or int(captain.site_follow_uid) == int(planned_site.uid)))
	assert(b.ai.PLAN_TO_BUILDING[b.ai.plan_item_for(10,3)] == 10 and b.ai.PLAN_TO_BUILDING[b.ai.plan_item_for(10,2)] == 11)
	print("AI CONSTRUCTION PASS existing idle team dispatch / busy team waits / reserved site / no combat hijack / granary plan mapping")
	var hp_before: float = planned_site.hp
	b.commands._kill(captain)
	for tick in range(8): b.commands._step_unit(worker,b.SIM_DT); b.commands._process_sites(b.SIM_DT)
	assert(planned_site.hp == hp_before and worker.build_target == null and worker.state != "build")
	assert(worker.group_officer == -1 and b.commands.ai_construction_commander(3).is_empty())
	print("CONSTRUCTION COMMANDER PASS commander loss dissolves work authority / members retained / site stops")
	b.free(); done = true; quit()
