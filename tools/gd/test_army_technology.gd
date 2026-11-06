extends SceneTree
const Rules = preload("res://simulation/systems/combat_rules.gd")
const State = preload("res://simulation/systems/technology_state.gd")
var done := false
var battle: Node2D
var game: Node

func _initialize() -> void:
	create_timer(75).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func spawn(type: int, owner: int) -> Dictionary:
	assert(battle.commands.world._spawn_unit(type,owner,1000,1800,true))
	return battle.units.back()

func saved() -> Dictionary:
	assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
	return game.load_save()

func by_uid(uid: int) -> Dictionary:
	return battle.units.filter(func(unit): return int(unit.uid) == uid)[0]

func run() -> void:
	game = root.get_node("Game"); game.current_map = "chibic13"
	battle = load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true; battle.ai = null
	assert(battle.player_owner == 3)
	var a := spawn(32,1); var b := spawn(32,2); var human := spawn(32,3)
	var worker := spawn(30,1); var building := spawn(2,1)
	var towers: Array = [spawn(18,1),spawn(19,1)]
	var corpse := spawn(32,1); battle.commands.military._kill(corpse,{})
	var dead_hp: float = corpse.hp
	var dead_max: float = corpse.maxhp
	a.hp -= 20
	var human_before := [human.hp,human.maxhp,human.attack_bonus,human.attack_b_bonus,human.defence_bonus]
	var b_before := [b.hp,b.maxhp,b.attack_bonus]
	# Execute the confirmed effects for AI1; scheduling is deliberately outside this probe.
	for index in [0,1,5,8,9,19,20,21,22]: battle.commands.technology._apply_tech_effects(index,1)
	assert(battle.commands.economy.ai_level(1) == 2 and battle.commands.economy.ai_level(2) == 0 and battle.commands.economy.ai_level(3) == 0)
	assert(a.hp == a.base_maxhp - 20 + 800 and a.maxhp == a.base_maxhp)
	assert(worker.hp == worker.base_maxhp and building.hp == building.base_maxhp and building.maxhp == building.base_maxhp + 800)
	for tower in towers: assert(tower.maxhp == tower.base_maxhp and tower.hp == tower.base_maxhp)
	assert(corpse.hp == dead_hp and corpse.maxhp == dead_max and corpse.die_t >= 0)
	assert(human_before == [human.hp,human.maxhp,human.attack_bonus,human.attack_b_bonus,human.defence_bonus])
	assert(b_before == [b.hp,b.maxhp,b.attack_bonus] and battle.player_tech == State.initial())
	var current_hp: float = a.hp
	for index in [0,1,0,8,6,8]: battle.commands.technology._apply_tech_effects(index,1)
	assert(a.hp == current_hp and a.attack_bonus == 9 and battle.commands.economy.ai_level(1) == 2)
	var born := spawn(32,1)
	assert(born.maxhp == born.base_maxhp and born.hp == born.base_maxhp + 800 and born.attack_bonus == 9)
	print("ARMY TECH ISOLATION PASS AI result only / worker-building HP / both towers exempt / dead body unchanged / monotonic completion / new spawn")
	# Two AI factions have different research while the player remains unresearched.
	for index in [0,3,4,5,6,11,18,20]: battle.commands.technology._apply_tech_effects(index,2)
	assert(b.hp == b.base_maxhp + 400 and b.attack_bonus == 3 and b.defence_bonus == 6)
	var fleets := {}
	for owner in [1,2]:
		var row := {}
		for type in [34,47,46,48,49]: row[type] = spawn(type,owner)
		fleets[owner] = row
	assert(Rules.attack(fleets[1][34],true) == 170 and Rules.attack(fleets[2][34],true) == 160)
	assert(Rules.defence(fleets[1][47]) == 15 and Rules.defence(fleets[1][47],true) == 5)
	assert(Rules.defence(fleets[2][47]) == 15 and Rules.defence(fleets[2][47],true) == 15)
	assert(Rules.defence(fleets[1][46]) == fleets[1][46].defence + 6 and Rules.defence(fleets[1][48],true) == fleets[1][48].defence_b + 10)
	assert(fleets[1][48].attack_b_bonus == 15 and fleets[2][48].attack_b_bonus == 0)
	assert(fleets[1][49].attack_b_bonus == 20 and fleets[2][49].attack_b_bonus == 10)
	assert(fleets[1][49].defence_bonus == 15 and fleets[2][49].defence_bonus == 0)
	for owner in fleets: assert(not Rules.can_attack(fleets[owner][47]))
	# Actual unit simulation consumes AI1's weapon research against an unresearched player.
	var hp: float = human.hp
	a.ax = human.ax; a.ay = human.ay; a.state = "attack"; a.target = human; a.cool = 0
	var damage := maxi(1,int(a.attack + 9 - human.defence))
	assert(battle.commands.military._damage(a,human) == damage)
	for tick in range(300):
		battle.commands.orders._step_unit(a,battle.SIM_DT)
		if human.hp < hp: break
	assert(human.hp == hp - damage)
	print("ARMY TECH COMBAT PASS two independent AI / ordinary weapons and armour / catapult / ships / transport unarmed / actual attack")
	var a_uid: int = a.uid; var b_uid: int = b.uid; var born_uid: int = born.uid
	var good := saved()
	assert(good.simulation.armyTech.has("1") and good.simulation.armyTech.has("2"))
	var before := JSON.stringify(good.units)
	# Reject corrupt ownership or research before touching the world or selection.
	battle.selected = [a]
	var invalid_cases: Array = []
	for value in [-1,0.5,4,"3",NAN,INF]:
		var invalid: Dictionary = good.duplicate(true); invalid.simulation.armyTech["1"].weapon = value; invalid_cases.append(invalid)
	for key in ["0","3","4","1.0","01","bad"]:
		var invalid: Dictionary = good.duplicate(true); invalid.simulation.armyTech[key] = State.initial(); invalid_cases.append(invalid)
	for value in [[],"broken",{"unknown":1},{"ship_atk":3},{"ship_def":2}]:
		var invalid: Dictionary = good.duplicate(true); invalid.simulation.armyTech["1"] = value; invalid_cases.append(invalid)
	for invalid in invalid_cases:
		assert(not battle.saver.apply_snapshot(invalid))
		assert(is_same(battle.selected[0],a) and JSON.stringify(saved().units) == before)
	# Deliberately wrong cached bonuses are recomputed from each owner's saved state.
	for record in good.units:
		record.simulation.attack_bonus = 999; record.simulation.defence_bonus = 999
	assert(battle.saver.apply_snapshot(good))
	a = by_uid(a_uid); b = by_uid(b_uid); born = by_uid(born_uid)
	assert(a.attack_bonus == 9 and b.attack_bonus == 3 and battle.commands.economy.ai_level(1) == 2 and battle.commands.economy.ai_level(2) == 1)
	assert(a.hp == current_hp and born.hp == born.base_maxhp + 800)
	var hp_after: float = born.hp
	battle.commands.technology._apply_tech_effects(1,1); assert(born.hp == hp_after)
	# Old v6 snapshot without armyTech starts AI research at zero, not stale live values.
	var old := saved(); old.simulation.erase("armyTech")
	assert(battle.saver.apply_snapshot(old) and battle.commands.economy.ai_level(1) == 0 and battle.commands.economy.ai_level(2) == 0)
	assert(by_uid(a_uid).attack_bonus == 0, str(by_uid(a_uid).attack_bonus))
	assert(battle.player_tech.values().all(func(value): return float(value) == 0))
	print("ARMY TECH SAVE PASS per-owner levels and HP / cached bonuses ignored / invalid state atomic / legacy missing field resets AI")
	battle.free()
	# Fourth faction is a real participant on the Xiangyang map, not a fabricated owner.
	game.current_map = "chibic6"
	battle = load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.ai = null
	var fourth := spawn(32,4)
	battle.commands.technology._apply_tech_effects(6,4)
	assert(fourth.attack_bonus == 3 and battle.commands.technology._tech_for(2).weapon == 0 and battle.player_tech.weapon == 0)
	assert(battle.saver.apply_snapshot(saved()))
	print("ARMY TECH FACTIONS PASS all four faction IDs, including multi-enemy chapters")
	battle.free(); done = true; quit()
