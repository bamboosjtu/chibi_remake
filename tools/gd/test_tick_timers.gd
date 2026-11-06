extends SceneTree
const Timers = preload("res://simulation/systems/tick_timers.gd")
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
	var data := snapshot()
	data.erase("savedAt")
	data.erase("checksum")
	return JSON.stringify(data)

func run() -> void:
	game = root.get_node("Game")
	game.current_map = "chibil1"
	b = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	for u in b.units: b.commands._cancel_unit_command(u); u.hold = true
	var hero: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and b.commands._is_hero_unit(u))[0]
	var workers: Array = b.units.filter(func(u): return u.owner == b.player_owner and int(u.unit) == 30)
	var site: Dictionary = b.units.filter(func(u): return u.owner == b.player_owner and u.is_building and int(u.unit) in [0,1])[0]
	var hero_uid: int = hero.uid
	var worker_ids := [int(workers[0].uid), int(workers[1].uid)]
	var site_uid: int = site.uid
	hero.hp = hero.maxhp - 10; hero.state = "rest"
	for tick in range(9): b.commands._step_unit(hero, b.SIM_DT)
	assert(hero.rest_t is int and hero.rest_t == 9 and hero.hp == hero.maxhp - 10)
	var rest_save := snapshot()
	assert(rest_save.v == game.SAVE_VERSION and b.saver.apply_snapshot(rest_save))
	hero = find_unit(hero_uid)
	b.commands._step_unit(hero, b.SIM_DT)
	assert(hero.rest_t == 0 and hero.hp == hero.maxhp - 9, "saved ninth tick must heal on next tick")
	for tick in range(90): b.commands._step_unit(hero, b.SIM_DT)
	assert(hero.hp == hero.maxhp and hero.state == "idle" and hero.rest_t == 0)
	hero.hp -= 1; hero.state = "rest"
	for tick in range(7): b.commands._step_unit(hero, b.SIM_DT)
	b.commands._cancel_unit_command(hero)
	assert(hero.rest_t == 0 and hero.state == "idle")
	print("TIMER REST PASS ninth-tick save / tenth-tick heal / full exit / command reset")
	# 两名工人分别累计；在 HP=0 工地上保存，不能把工地读成阵亡对象。
	site = find_unit(site_uid); site.site = true; site.hp = 0
	workers = [find_unit(worker_ids[0]), find_unit(worker_ids[1])]
	for worker in workers:
		var path: Array = b.commands._site_entry_path(worker, site)
		assert(not path.is_empty())
		worker.ax = path.back().x; worker.ay = path.back().y
		worker.state = "build"; worker.build_target = site; worker.build_t = 0
		b.construction.enter(worker, site)
	for tick in range(3):
		for worker in workers: b.commands._step_unit(worker, b.SIM_DT)
	assert(site.hp == 0 and workers.all(func(w): return w.build_t is int and w.build_t == 3))
	var build_save := snapshot()
	assert(b.saver.apply_snapshot(build_save))
	site = find_unit(site_uid); workers = [find_unit(worker_ids[0]), find_unit(worker_ids[1])]
	assert(site.alive and site.site and site.hp == 0)
	for worker in workers: b.commands._step_unit(worker, b.SIM_DT)
	assert(site.hp == 4 and workers.all(func(w): return w.build_t == 0))
	var cash: Dictionary = b.commands._resources().duplicate()
	b.commands._cancel_unit_command(workers[0])
	for tick in range(4): b.commands._step_unit(workers[1], b.SIM_DT)
	assert(site.alive and site.site and site.hp == 6 and b.commands._resources() == cash)
	assert(workers[0].build_target == null and workers[0].build_t == 0)
	site.hp = site.maxhp - 2
	for tick in range(4): b.commands._step_unit(workers[1], b.SIM_DT)
	assert(not site.site and site.hp == site.maxhp and workers[1].state == "idle" and workers[1].build_t == 0)
	print("TIMER BUILD PASS third-tick zero-HP save / fourth-tick 2HP per worker / shared site / completion")
	# 六个状态使用同一边界；delta 刻意变化，不能把一次逻辑调用解释为真实秒。
	hero = find_unit(hero_uid); hero.state = "idle"; hero.hold = true
	for key in Timers.STATUS_KEYS: hero[key] = 800
	for tick in range(799): b.commands._step_unit(hero, 0.001 if tick % 2 == 0 else 0.1)
	assert(Timers.STATUS_KEYS.all(func(key): return hero[key] is int and hero[key] == 1))
	var effects_save := snapshot()
	assert(effects_save.units.filter(func(r): return r.uid == hero_uid)[0].simulation.farsight_t == 1)
	assert(b.saver.apply_snapshot(effects_save))
	hero = find_unit(hero_uid)
	b.commands._step_unit(hero, b.SIM_DT)
	assert(Timers.STATUS_KEYS.all(func(key): return hero[key] == 0))
	# 经真实计谋入口验证刷新和加减速互斥，不仅测试计时工具函数。
	hero.officer.level = 9; hero.mou = 10000; b.selected = [hero]
	b.commands._jimou_begin(1); assert(b.jimou_pending == 1)
	b.commands._jimou_cast_at(Vector2(hero.ax, hero.ay))
	assert(hero.haste_t == 800 and hero.slow_t == 0)
	b.commands._step_unit(hero, b.SIM_DT)
	b.commands._jimou_begin(1); b.commands._jimou_cast_at(Vector2(hero.ax, hero.ay))
	assert(hero.haste_t == 800, "reapplying refreshes exact duration")
	var enemy: Dictionary = b.units.filter(func(u): return u.owner != 0 and u.owner != b.player_owner and not u.is_building)[0]
	enemy.ax = hero.ax + 100; enemy.ay = hero.ay; enemy.haste_t = 300
	b.commands._jimou_begin(2); b.commands._jimou_cast_at(Vector2(enemy.ax, enemy.ay))
	assert(enemy.slow_t == 800 and enemy.haste_t == 0)
	print("TIMER STATUS PASS six x800 / expiry save / farsight saved / real cast refresh / mutual exclusion")
	# v4/v5 秒值先迁移再按模型类型写入；不能先 int() 秒值丢失小数。
	hero.rest_t = 9; hero.build_t = 3; hero.burn_t = 2.5; hero.burn_dps = 20
	for key in Timers.STATUS_KEYS: hero[key] = 799
	var current := snapshot()
	for version in [4,5]:
		var legacy: Dictionary = current.duplicate(true)
		legacy.v = version
		for record in legacy.units:
			for key in Timers.STATUS_KEYS + Timers.ELAPSED_PERIODS.keys():
				record.simulation[key] = float(record.simulation[key]) / 30.0
			record.simulation.erase("farsight_t") # 旧正式档没有该字段。
		assert(b.saver.apply_snapshot(legacy))
		hero = find_unit(hero_uid)
		assert(hero.rest_t == 9 and hero.build_t == 3 and hero.farsight_t == 0 and hero.inspired_t == 799)
		assert(hero.burn_t == 2.5 and hero.burn_dps == 20, "burn approximation must not change units")
	assert(b.saver.apply_snapshot(current))
	hero = find_unit(hero_uid); b.selected = [hero]
	var before := world_text()
	for pair in [["rest_t",10],["build_t",4],["haste_t",801],["farsight_t",-1],["inspired_t",0.5],["hidden_t","2"],["confused_t",null],["slow_t",NAN],["rest_t",INF]]:
		var invalid: Dictionary = current.duplicate(true)
		invalid.units.filter(func(r): return r.uid == hero_uid)[0].simulation[pair[0]] = pair[1]
		assert(not b.saver.apply_snapshot(invalid), "invalid tick must be rejected before world exchange")
		assert(b.selected.size() == 1 and is_same(b.selected[0], hero) and world_text() == before)
	var missing: Dictionary = current.duplicate(true)
	for record in missing.units:
		for key in Timers.STATUS_KEYS + Timers.ELAPSED_PERIODS.keys(): record.simulation.erase(key)
	assert(b.saver.apply_snapshot(missing))
	hero = find_unit(hero_uid)
	assert((Timers.STATUS_KEYS + Timers.ELAPSED_PERIODS.keys()).all(func(key): return hero[key] is int and hero[key] == 0))
	print("TIMER SAVE PASS v6 / v4-v5 migration / missing defaults / invalid atomic / burn unchanged")
	# 同一40tick在四档速度、不同渲染帧率下结果相同。
	hero.hp = hero.maxhp - 100; hero.state = "rest"; hero.hold = true; hero.burn_t = 0
	hero.haste_t = 800
	for u in b.units:
		if int(u.uid) != hero_uid: b.commands._cancel_unit_command(u); u.hold = true
	b.sim_tick = 0; b.sim_acc = 0
	var speed_save := snapshot()
	for speed in range(4):
		for fps in [30,144]:
			assert(b.saver.apply_snapshot(speed_save)); b.ai = null
			b.commands.set_sim_speed(speed)
			var elapsed := 0.0
			var duration: float = 40 * b.clock.period()
			while elapsed < duration - 0.000000001:
				var frame := minf(1.0 / fps, duration - elapsed)
				b._process(frame); elapsed += frame
			while b.sim_acc + 0.000000001 >= b.clock.period(): b._process(0)
			hero = find_unit(hero_uid)
			assert(b.sim_tick == 40 and hero.hp == hero.maxhp - 96 and hero.rest_t == 0 and hero.haste_t == 760)
	print("TIMER SPEED PASS four speeds x30/144fps / same40tick healing and expiry")
	b.free(); done = true; quit()
