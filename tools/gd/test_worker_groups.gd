extends SceneTree
## 真正步进工人的移动、采集和运输；不调用 _sim_step，排除被动收入。
var finished := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not finished: quit(1))
	_run.call_deferred()
func _battle() -> Node2D:
	root.get_node("Game").current_map = "chibil1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	load(get_script().resource_path.get_base_dir().path_join("economy_fixture.gd")).warehouses(battle)
	battle.set_process(false); battle.cli_mode = true
	return battle
func _work_tick(battle: Node2D, workers: Array) -> void:
	battle.commands.world._update_gates()
	for worker in workers: battle.commands.orders._step_unit(worker, 1.0 / 30.0)
	battle.visibility.update(battle.units, battle.player_owner)
func _run() -> void:
	for resource in [102, 100, 22, 24]:
		var battle := _battle()
		var workers: Array = []
		for u in battle.units:
			if int(u.unit) == 30 and int(u.owner)==battle.player_owner: workers.append(u)
		assert(workers.size() == 4)
		# 新研究：单选将本体，才能发整队采集指令。
		battle.selected = [battle.units.filter(func(u):return int(u.owner)==battle.player_owner and not u.officer.is_empty())[0]]
		var origin := Vector2(workers[0].ax, workers[0].ay)
		var objects: Array = battle.decor_targets.duplicate()
		objects.append_array(battle.units)
		objects = objects.filter(func(o): return int(o.unit) == resource)
		objects.sort_custom(func(a,b): return origin.distance_squared_to(Vector2(a.ax,a.ay)) < origin.distance_squared_to(Vector2(b.ax,b.ay)))
		var target: Dictionary = objects[0]
		# 本项验证“交付不改变资源种类/不产生被动收入”；给足存量，避免把
		# “视野内无同类资源时按规则停止”误判成交付错误（采空转采见 test_harvest_retarget.gd）。
		if bool(target.get("decor", false)):
			for cell in battle.commands.orders._resource_patch_cells(target):
				var source: Dictionary = battle.decor_cells["%d_%d" % [cell.x, cell.y]]
				source.stock = 20000.0; source.stock_max = 20000.0
		else:
			target.stock = 20000.0; target.stock_max = 20000.0
		var before: Dictionary = battle.commands.world._resources()
		battle.commands.orders._order_context(Vector2(target.ax, target.ay - minf(20, target.h * 0.5)))
		for w in workers:
			assert(w.state == "gather" and int(w.gather_obj.unit) == resource, "right click must retain requested resource kind")
			if not bool(target.get("decor", false)):
				assert(w.gather_obj == target, "building resource keeps its explicit target")
		var collected := {}
		var delivered := {}
		var steps := 0
		while steps < 18000 and delivered.values().reduce(func(a, n): return a + int(n), 0) < 8:
			battle.commands.world._update_gates()
			for w in workers:
				var cargo: float = w.carry
				battle.commands.orders._step_unit(w, 1.0 / 30.0)
				if w.carry > 0: collected[w.uid] = true
				if cargo > 0 and w.carry == 0: delivered[w.uid] = int(delivered.get(w.uid, 0)) + 1
				assert(w.gather_obj != null and battle.commands.economy._yield_of(int(w.gather_obj.unit)) == battle.commands.economy._yield_of(resource), "delivery keeps the requested resource kind")
			steps += 1
		var after: Dictionary = battle.commands.world._resources()
		var kind: String = battle.commands.economy._yield_of(resource)
		print("WORKER CYCLE resource=", resource, " kind=", kind, " simulatedSeconds=",steps/30.0," collected=",collected.size()," deposited=",delivered.size()," income=",after[kind]-before[kind])
		assert(delivered.size() == 4 and after[kind] - before[kind] >= 1600)
		for other in before:
			if other != kind: assert(before[other] == after[other], "no passive / unrelated income")
		battle.free()
	var battle := _battle()
	var hero: Dictionary = battle.selected[0]
	var hero_uid: int = hero.uid
	var original: Array = battle.units.filter(func(w): return int(w.unit)==30 and int(w.owner)==battle.player_owner)
	assert(battle.commands.military._order_disband() == 1)
	# 原版模式 6（FUN_0045dc90）：解散会**清空选择**、解绑成员、把将移出 20 将列表。
	assert(not battle.units.has(hero) and battle.selected.is_empty() and not battle.commands.military.officer_in_use(42))
	for worker in original:
		assert(worker.alive and worker.unit == 30 and worker.group_officer == -1)
	# 重新组建前先把成员选回来（原版 UI 也是这样：解散后重新框选）
	battle.selected = original.duplicate()
	battle.commands.military._order_form_up(42)
	assert(battle.selected.size() == 1 and battle.commands.military.officer_in_use(42))
	var replacement: Dictionary = battle.selected[0]
	assert(replacement.uid != hero_uid and replacement.unit == 29 and replacement.officer.index == 42)
	for worker in original:
		assert(battle.units.has(worker) and worker.unit == 30 and worker.group_officer == 42)
	var count: int = battle.units.size()
	battle.commands.military._order_form_up(42)
	assert(battle.units.size() == count, "cannot duplicate an officer")
	assert(root.get_node("Game").save_game(battle.units, battle.commands.world._resources(), battle.commands.session._save_extra()))
	var snapshot: Dictionary = root.get_node("Game").load_save()
	assert(battle.saver.apply_snapshot(snapshot))
	var restored: Dictionary = {}
	original = []
	for unit in battle.units:
		if int(unit.get("officer", {}).get("index", -1)) == 42: restored = unit
		if unit.owner == battle.player_owner and int(unit.unit) == 30: original.append(unit)
	assert(not restored.is_empty())
	battle.commands.orders._select_click(Vector2(restored.ax, restored.ay - restored.h * 0.5), false)
	assert(battle.selected.size() == 1 and battle.selected[0].officer.index == 42)
	assert(battle.commands.military._order_disband() == 1)
	battle.selected = battle.units.filter(func(w): return w.owner == battle.player_owner and not w.is_building and int(w.unit) == 30)
	assert(battle.selected.size() == 4)
	battle.commands.military._order_form_up(42)
	assert(battle.selected.size() == 1)
	print("GROUP PASS independent commander / four original workers / disband / regroup / save-load / repeat")
	var mine: Dictionary = {}
	for unit in battle.units:
		if int(unit.unit) == 22: mine = unit; break
	battle.commands.economy._order_gather(mine)
	for step in range(1500):
		_work_tick(battle, original)
		if original.any(func(w): return float(w.carry) > 0): break
	assert(original.any(func(w): return float(w.carry) > 0))
	assert(root.get_node("Game").save_game(battle.units, battle.commands.world._resources(), battle.commands.session._save_extra()))
	var working: Dictionary = root.get_node("Game").load_save()
	for step in range(1200):
		_work_tick(battle, original)
	assert(root.get_node("Game").save_game(battle.units, battle.commands.world._resources(), battle.commands.session._save_extra()))
	var expected: Dictionary = root.get_node("Game").load_save()
	assert(battle.saver.apply_snapshot(working))
	original = battle.units.filter(func(w): return w.owner == battle.player_owner and int(w.unit) == 30)
	for step in range(1200):
		_work_tick(battle, original)
	assert(root.get_node("Game").save_game(battle.units, battle.commands.world._resources(), battle.commands.session._save_extra()))
	var actual: Dictionary = root.get_node("Game").load_save()
	expected.erase("savedAt"); actual.erase("savedAt")
	expected.erase("checksum"); actual.erase("checksum")
	if JSON.stringify(expected) != JSON.stringify(actual):
		var first := FileAccess.open("user://harvest-expected.json", FileAccess.WRITE)
		first.store_string(JSON.stringify(expected)); first.close()
		var second := FileAccess.open("user://harvest-actual.json", FileAccess.WRITE)
		second.store_string(JSON.stringify(actual)); second.close()
	assert(JSON.stringify(expected) == JSON.stringify(actual), "harvest/transport continuation differs after load")
	# 反转快照实体顺序，专测资源实体在工人之后的前向引用。
	working.units.reverse()
	assert(battle.saver.apply_snapshot(working))
	original = battle.units.filter(func(w): return w.owner == battle.player_owner and int(w.unit) == 30)
	for w in original: assert(w.gather_obj != null and int(w.gather_obj.unit) == 22)
	print("WORKER SAVE PASS mid-cargo + 40 second continuation / forward resource references")
	# 真实地图南侧最底一行可走格：从开局寻路并逐 tick 行走，不能只测相机数学。
	battle.free()
	battle = _battle()
	original = battle.units.filter(func(w): return int(w.unit) == 30 and int(w.owner)==battle.player_owner)
	var worker: Dictionary = original[0]
	var south := Vector2.ZERO
	var route: Array = []
	for y in range(int(battle.map_data.cols)-1, -1, -1):
		for x in range(int(battle.map_data.rows)):
			if battle.nav.is_solid(Vector2i(x,y)): continue
			if not battle.commands.world._cell_unit(Vector2i(x,y)).is_empty(): continue
			var point: Vector2 = battle.nav.anchor_of(x,y)
			route = battle.commands.orders._path_to(worker, point, true)
			if not route.is_empty():
				south = point; break
		if not route.is_empty(): break
	assert(not route.is_empty() and south.y > float(battle.map_data.terrainH)*0.9)
	worker.state = "move"; worker.path = route; worker.pi = 0
	var walked := 0
	while worker.state == "move" and walked < 18000:
		battle.commands.world._update_gates()
		battle.commands.orders._step_unit(worker, 1.0 / 30.0); walked += 1
	assert(Vector2(worker.ax,worker.ay).distance_to(south) < 8, "walk to actual southern map edge")
	print("SOUTH PASS destination=",south," actual=",Vector2(worker.ax,worker.ay)," simulatedSeconds=",walked/30.0)
	battle.free()
	finished = true; quit()
