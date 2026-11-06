extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	for map_id in ["chibil1", "chibil2", "chibil3"]:
		root.get_node("Game").current_map = map_id
		var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle)
		battle.set_process(false); battle.cli_mode = true; battle.ai = null
		var leaders: Array = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and not u.get("officer", {}).is_empty())
		var expected := 41 if map_id == "chibil3" else 42
		var worker_leader: Dictionary = leaders.filter(func(u): return int(u.officer.index) == expected)[0]
		assert(str(worker_leader.officer.name).replace(" ", "") == ("诸葛亮" if expected == 41 else "徐庶"))
		var workers: Array = battle.commands.military._construction_workers(worker_leader)
		assert(workers.size() == 4 and workers.all(func(u): return int(u.unit) == 30 and int(u.group_officer) == expected))
		battle.selected = [worker_leader]
		assert(battle.commands.military._selected_construction_workers().size() == 4)
		if map_id == "chibil3":
			assert(leaders.size() == 2)
			var zhao: Dictionary = leaders.filter(func(u): return int(u.officer.index) == 33)[0]
			assert(str(zhao.officer.name).replace(" ", "") == "赵云")
			var fighters: Array = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and int(u.get("group_officer", -1)) == 33)
			assert(fighters.size() == 11 and fighters.all(func(u): return int(u.unit) in [32,36,45])) # 保持仓库现有4步/4骑/3弓编制。
			var types := {}
			for unit in fighters: types[int(unit.unit)] = true
			assert(types.size() == 3 and battle.commands.military._construction_workers(zhao).is_empty())
		else: assert(leaders.size() == 1)
		# 施工由武将发起；仅选队员和解散后的独立工人均不能发起建造。
		battle.selected = [workers[0]]
		assert(battle.commands.military._selected_construction_workers().is_empty())
		battle.selected = [worker_leader]; assert(battle.commands.military._order_disband() == 1)
		battle.selected = workers
		assert(battle.commands.military._selected_construction_workers().is_empty())
		var before: Dictionary = battle.commands.world._resources().duplicate()
		var size: int = battle.units.size()
		battle.commands.economy._start_build(battle.build_types[0])
		assert(battle.commands.orders.cmd_pending_kind() == "")
		assert(not battle.commands.economy._build_site_at(Vector2(workers[0].ax,workers[0].ay),battle.build_types[0]))
		assert(battle.commands.world._resources() == before and battle.units.size() == size)
		if map_id == "chibil3":
			var game := root.get_node("Game")
			battle.commands.technology._apply_tech_effects(0)
			assert(battle.commands.military._form_hero_unit(workers[0], expected))
			var hero: Dictionary = battle.units.back()
			var maximum: float = hero.base_maxhp
			assert(hero.hp == maximum and hero.maxhp == maximum)
			assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
			assert(battle.saver.apply_snapshot(game.load_save()))
			hero = battle.units.back()
			assert(hero.hp == maximum and hero.maxhp == maximum)
			battle.selected = [hero]; assert(battle.commands.military._order_disband() == 1)
			var unused: Dictionary = battle.commands.military.available_officers(battle.player_owner).filter(func(o): return int(o.get("exp",0)) == 0 and int(o.get("level",0)) == 0)[0]
			var index: int = unused.index
			var had_experience: bool = unused.has("exp")
			assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
			var snapshot: Dictionary = game.load_save()
			var saved_officer: Dictionary = snapshot.simulation.officerPool[str(index)]
			assert(saved_officer.exp == 0 and saved_officer.level == 0 and saved_officer.hasExp == had_experience)
			battle.selected = battle.units.filter(func(u): return u.alive and int(u.owner) == battle.player_owner and int(u.unit) == 30)
			assert(battle.commands.military._form_hero_unit(battle.selected[0],index))
			hero = battle.units.back(); battle.commands.military._grant_officer_exp(hero,600)
			battle.selected = [hero]; assert(battle.commands.military._order_disband() == 1)
			assert(battle.commands.military._officer_by_index(index).exp > 0)
			assert(battle.saver.apply_snapshot(snapshot))
			var restored: Dictionary = battle.commands.military._officer_by_index(index)
			assert(restored.get("exp",0) == 0 and restored.level == 0 and restored.has("exp") == had_experience)
			# Legacy saves omitted unchanged pool entries; that still rolls back
			# later progression to the chapter's initial zero experience.
			var legacy: Dictionary = snapshot.duplicate(true)
			legacy.simulation.officerPool.erase(str(index))
			assert(battle.saver.apply_snapshot(legacy))
			assert(battle.commands.military._officer_by_index(index).get("exp",0) == 0)
			battle.commands.military._restore_officer_pool({})
			assert(battle.commands.military._officer_by_index(0).level == 5)
			print("TEAM SNAPSHOT PASS hp=",maximum," rollbackExp=",restored.get("exp",0))
		print("INITIAL TEAMS PASS ",map_id," confirmed commanders / four workers / mixed army / independent worker cannot build")
		battle.free()
	# 16名待编组工人：至多15名随将入队，剩余单位保留且不消失。
	root.get_node("Game").current_map = "chibil1"
	var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true; battle.ai = null
	assert(battle.commands.military._order_disband() == 1)
	var original: Array = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and int(u.unit) == 30)
	for i in range(12): assert(battle.commands.world._spawn_unit(30,battle.player_owner,original[0].ax,original[0].ay,true))
	var workers: Array = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and int(u.unit) == 30)
	assert(workers.size() == 16)
	battle.selected = workers.duplicate()
	assert(battle.commands.military._form_hero_unit(workers[0],42))
	assert(battle.selected.size() == 1 and battle.commands.military._construction_workers(battle.selected[0]).size() == 15)
	assert(workers.filter(func(u): return int(u.group_officer) == -1).size() == 1)
	assert(workers.all(func(u): return u.alive and battle.units.has(u)))
	print("TEAM LIMIT PASS one commander plus15 members / extra worker retained / construction role preserved")
	# 超额快照有16名成员另加武将；读回时保留超额实体、HP和货物，只解除关联。
	var extra: Dictionary = workers.filter(func(u): return int(u.group_officer) == -1)[0]
	var extra_uid: int = extra.uid
	var extra_hp: float = extra.hp
	extra.group_officer = 42; extra.carry = 73; extra.carry_kind = "food"
	var count: int = battle.units.size()
	var game := root.get_node("Game")
	assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
	assert(battle.saver.apply_snapshot(game.load_save()))
	extra = battle.units.filter(func(u): return int(u.uid) == extra_uid)[0]
	assert(battle.units.size() == count and extra.alive and extra.hp == extra_hp and extra.group_officer == -1 and extra.carry == 73 and extra.carry_kind == "food")
	assert(battle.units.filter(func(u): return int(u.owner) == battle.player_owner and int(u.get("group_officer", -1)) == 42).size() == 15)
	print("TEAM MIGRATION PASS old overfull group releases excess member / UID-HP-cargo retained")
	battle.free(); done = true; quit()
