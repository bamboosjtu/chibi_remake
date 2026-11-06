extends SceneTree
const Store = preload("res://app/json_store.gd")   # batch2：json_store 迁入 app/，此处引用同步
var _done := false                                # 看门狗：断言失败中止 _run 后改由超时退出

func _initialize() -> void:
	# 断言失败会中止 _run、quit() 不再执行，进程便永远转帧（表现为外层超时）。
	# P0 退出条件要求"真实失败返回非零"——用定时器把卡死翻译成 FAIL + quit(1)。
	create_timer(120.0).timeout.connect(func() -> void:
		if not _done:
			printerr("ARCH TIMEOUT: _run 未在时限内完成（断言失败即此表现）")
			quit(1))
	_run.call_deferred()

func _run() -> void:
	var path := "user://store-test.json"
	assert(Store.commit(path, '{"generation":1}'))
	assert(Store.commit(path, '{"generation":2}'))
	var d := DirAccess.open("user://")
	assert(d.rename("store-test.json", "store-test.interrupted") == OK)
	assert(int(Store.read(path).generation) == 1)
	assert(d.rename("store-test.interrupted", "store-test.json") == OK)
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("broken")
	bad.close()
	assert(int(Store.read(path).generation) == 1)
	assert(not Store.commit(path, 'invalid'))
	assert(int(Store.read(path).generation) == 1)
	assert(Store.commit(path, '{"generation":3}'))
	assert(int(Store.read(path).generation) == 3)
	var nav = load("res://simulation/navigation/nav.gd").new()
	var walk := []
	walk.resize(48)
	walk.fill(1)
	nav.setup({"rows": 6, "cols": 8, "walkable": walk, "terrainWalkable": walk, "terrainW": 600, "terrainH": 300})
	var start: Vector2 = nav.anchor_of(1, 2)
	var end: Vector2 = nav.anchor_of(4, 6)
	var route: Array = nav.find_path(start, end, true)
	assert(not route.is_empty())
	for n in nav.neighbors(Vector2i(2, 2)):
		assert(n.y in [1, 3] and n.x in [1, 2])
	nav.block(Vector2i(4, 6))
	route = nav.find_path(start, end, true)
	assert(not route.is_empty() and route.back() != end)
	var footprint: Array[Vector2i] = nav.footprint(nav.anchor_of(2, 3), 88, 44)
	assert(footprint.size() > 1)
	assert(nav.can_place(footprint))
	nav.occupy(footprint, 1)
	assert(not nav.can_place(footprint))
	nav.occupy(footprint, -1)
	assert(nav.can_place(footprint))
	print("ARCH-019 PASS: staggered neighbors, blocked exact target, multi-cell occupancy")
	var game := root.get_node("Game")
	game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var u: Dictionary = battle.units[0]
	var enemy: Dictionary = battle.units.back()
	u.hold = true
	u.cool = 0.75
	u.state = "move"
	u.path = [Vector2(u.ax + 44, u.ay)]
	u.pi = 0
	u.target = enemy
	battle.control_groups = {1: [u.uid]}
	battle.sim_tick = 731
	battle.ai_res = {2: {"gold": 999.0, "wood": 80.0, "food": 71.0, "stone": 66.0}}
	battle.task_latches = {"first": true}
	battle.ai._think = {2: 17}
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var snapshot: Dictionary = game.load_save()
	assert(battle.saver.apply_snapshot(snapshot))
	u = battle.units[0]
	assert(u.hold and is_equal_approx(u.cool, 0.75))
	assert(u.path.size() == 1 and u.target.uid == enemy.uid)
	assert(battle.sim_tick == 731 and battle.ai._think[2] == 17)
	assert(battle.ai_res[2].gold == 999.0 and battle.control_groups[1].size() == 1)
	assert(not u.has("spr"))
	var wrong: Dictionary = snapshot.duplicate(true)
	wrong.simulation.contentRevision = "invalid"
	assert(not battle.saver.apply_snapshot(wrong))
	print("ARCH-017/018 PASS: crash recovery, content revision, no-view full snapshot")
	# 同一快照继续执行两个 tick，必须与未载入分支逐字段一致。
	u.state = "idle"; u.target = null; u.path = []; u.pi = 0
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var before: Dictionary = game.load_save()
	battle.commands._sim_step(battle.SIM_DT)
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var expected: Dictionary = game.load_save()
	assert(battle.saver.apply_snapshot(before))
	battle.commands._sim_step(battle.SIM_DT)
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var actual: Dictionary = game.load_save()
	expected.erase("savedAt"); actual.erase("savedAt")
	expected.erase("checksum"); actual.erase("checksum")
	var expected_text := JSON.stringify(expected)
	var actual_text := JSON.stringify(actual)
	if expected_text != actual_text:
		var dump := FileAccess.open("user://arch_expected.json", FileAccess.WRITE)
		if dump != null:
			dump.store_string(expected_text); dump.close()
		dump = FileAccess.open("user://arch_actual.json", FileAccess.WRITE)
		if dump != null:
			dump.store_string(actual_text); dump.close()
	assert(expected_text == actual_text, "Snapshot continuation diverged (dumps in user://)")
	print("ARCH-018 continuation PASS")
	# 在行军、追击、警戒和生产计时同时进行时比较下一 tick。
	var mobiles := []
	var production := {}
	for unit in battle.units:
		if not unit.is_building and int(unit.owner) == int(battle.player_owner): mobiles.append(unit)
		if unit.is_building: production = unit
	assert(mobiles.size() >= 3 and not production.is_empty())
	var mover: Dictionary = mobiles[0]
	var mover_cell: Vector2i = battle.nav.cell_of_px(mover.ax, mover.ay)
	for next in battle.nav.neighbors(mover_cell):
		if not battle.nav.is_solid(next):
			mover.path = battle.nav.find_path(Vector2(mover.ax, mover.ay), battle.nav.anchor_of(next.x, next.y), false)
			if not mover.path.is_empty(): break
	assert(not mover.path.is_empty())
	mover.state = "move"; mover.pi = 0; mover.hold = false
	# 上一次 apply_snapshot 已交换实体字典；必须重新取得敌军引用，不能给
	# 一条分支喂已脱离世界的旧对象、另一条分支喂按 uid 解析的真实目标。
	var enemy_uid: int = int(enemy.uid)
	for candidate in battle.units:
		if int(candidate.uid) == enemy_uid: enemy = candidate; break
	assert(enemy in battle.units)
	mobiles[1].state = "attack"; mobiles[1].target = enemy; mobiles[1].cool = 0.5
	mobiles[2].hold = true
	battle.trainings = [{"owner": 4, "b": production, "unit": 30, "t": 2.0, "ticks": true, "cost": {"gold": 50}}]
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var concurrent: Dictionary = game.load_save()
	battle.commands._sim_step(battle.SIM_DT)
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var continued: Dictionary = game.load_save()
	assert(battle.saver.apply_snapshot(concurrent))
	assert(battle.trainings[0].owner == 4)
	battle.commands._sim_step(battle.SIM_DT)
	assert(game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()))
	var recovered: Dictionary = game.load_save()
	continued.erase("savedAt"); recovered.erase("savedAt")
	continued.erase("checksum"); recovered.erase("checksum")
	if JSON.stringify(continued) != JSON.stringify(recovered):
		Store.commit("user://continuation-expected.json", JSON.stringify(continued))
		Store.commit("user://continuation-actual.json", JSON.stringify(recovered))
	assert(JSON.stringify(continued) == JSON.stringify(recovered), "Concurrent continuation diverged")
	print("ARCH-018 concurrent PASS: moving, combat, hold, production owner")
	# 八号任务：终点先到不算完成；桥头只执行一次，开启后到终点才胜利。
	battle.scenario_mission = 8
	battle.task_latches = {}; battle.task_events = []; battle.objective_done = false
	var hero: Dictionary = battle.units[0]
	hero.owner = battle.player_owner
	hero.officer = {"index": 33}
	hero.A = 95; hero.B = 300
	assert(battle.rules.tick() == 0)
	hero.A = 10; hero.B = 84
	assert(battle.rules.tick() == 0)
	assert(battle.task_events.size() == 1 and battle.terrain_changes.has("1/10/84"))
	assert(battle.rules.tick() == 0 and battle.task_events.size() == 1)
	hero.A = 95; hero.B = 300
	assert(battle.rules.tick() == 1)
	battle.selected = [hero]
	hero.is_building = false; hero.state = "move"; hero.path = [Vector2.ZERO]
	battle.commands.stop_selected()
	assert(hero.state == "idle" and hero.path.is_empty() and hero.target == null)
	print("ARCH-020/023 PASS: ordered task latches, once-only bridge event, command boundary")
	var actual_units: Array = battle.units
	var leader := _fixture_unit(battle.player_owner, 60)
	var one := _fixture_unit(battle.player_owner, 34)
	var two := _fixture_unit(battle.player_owner, 35)
	var three := _fixture_unit(battle.player_owner, 36)
	battle.units = [leader, one, two, three]
	for mission in [14, 30]:
		battle.scenario_mission = mission
		battle.task_latches = {}; battle.task_events = []; battle.objective_done = false
		for other in [one, two, three]:
			other.owner = battle.player_owner if mission == 14 else 2
			if int(other.owner) == int(battle.player_owner) and mission == 30:
				other.owner = 3
		assert(battle.rules.tick() == 0 and battle.task_events.size() == 1)
		assert(battle.rules.tick() == 0 and battle.task_events.size() == 2)
		assert(battle.rules.tick() == 1 and battle.task_events.size() == 3)
		assert(battle.rules.tick() == 1 and battle.task_events.size() == 3)
		assert(int(leader.status_173) == (110 if mission == 14 else 70))
	for entry in [[19, 50, 60], [20, 63, 241], [29, 54, 171]]:
		battle.scenario_mission = int(entry[0])
		battle.task_latches = {}; battle.task_events = []; battle.objective_done = false
		battle.officer_progress = {}
		leader.A = int(entry[1]); leader.B = int(entry[2])
		battle.units = [leader, one]
		one.owner = 2 if battle.player_owner != 2 else 3
		assert(battle.rules.tick() == 0)
		assert(int(one.event_experience) == 100)
		assert(battle.rules.tick() == 0 and int(one.event_experience) == 100)
		assert(battle.task_latches.size() == 1)
	battle.scenario_mission = 27
	battle.task_latches = {}; battle.task_events = []
	leader.unit = 49
	assert(battle.rules.tick() == 0 and battle.task_events.size() == 1)
	assert(battle.rules.tick() == 0 and battle.task_events.size() == 1)
	battle.units = actual_units
	print("ARCH-020 PASS: missions 14/30 proximity, 19/20/29 orders and experience, 27 event")
	# Budget arithmetic must work in a clean checkout without baked terrain.
	# A synthetic map avoids loading gate patches or requiring LFS textures.
	var stream = load("res://presentation/battle/terrain_stream.gd").new(battle, "__budget_fixture__")
	for i in range(100):
		stream.chunks.append({"rect":[i*256,0,256,256],"lods":{
			"4":{"bytes":1024*1024*4},
			"2":{"bytes":512*512*4},
			"1":{"bytes":256*256*4},
		}})
	var all := []
	for i in range(stream.chunks.size()):
		all.append(i)
	assert(stream.estimate(all, 4) > stream.budget)
	assert(stream.estimate(all.slice(0, 10), 4) <= stream.budget)
	assert(stream.estimate(all, 4) == 100*1024*1024*4)
	assert(stream.estimate(all, 2) <= stream.resident_limit())
	assert(stream.estimate(all, 1)*4 == stream.estimate(all, 2))
	stream.free()
	print("ARCH-022 budget selection PASS")
	battle.free()
	_done = true
	quit()

func _fixture_unit(owner: int, officer: int) -> Dictionary:
	return {"owner": owner, "officer": {"index": officer - 1}, "unit": 27,
		"alive": true, "die_t": -1.0, "is_building": false, "A": 80, "B": 180,
		"ax": 1000.0, "ay": 800.0, "status_173": 70, "event_experience": 0,
		"path": [], "pi": 0, "state": "idle"}

