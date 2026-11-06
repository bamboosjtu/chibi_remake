extends SceneTree
var done := false
var battle: Node2D
var caster: Dictionary
var enemy: Dictionary

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func point() -> Vector2:
	return Vector2(enemy.ax,enemy.ay - enemy.h * 0.5)

func refresh() -> void:
	battle.visibility.update(battle.units,battle.player_owner)

func rejected() -> void:
	var hp := [caster.hp,enemy.hp]
	battle.simulation_rng.seed=81; var next:int = battle.simulation_rng.randi(); battle.simulation_rng.seed=81
	battle.commands.military._duel_at(point())
	assert(not battle.duel_pending and [caster.hp,enemy.hp] == hp and battle.simulation_rng.randi() == next)

func run() -> void:
	var game := root.get_node("Game"); game.current_map = "chibil1"
	battle = load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true; battle.ai = null
	caster = battle.selected[0]
	enemy = battle.units.filter(func(u): return u.owner != battle.player_owner and not u.get("officer",{}).is_empty())[0]
	caster.vision = 20
	enemy.ax = caster.ax + battle.tile_w * 2; enemy.ay = caster.ay; refresh()
	assert(is_same(battle.commands.orders._enemy_at(point()),enemy))
	# Caster is revalidated on confirmation, including a control-group change to flagship.
	for property in ["flagship","dying","attached","foreign","stale"]:
		battle.selected = [caster]; battle.commands.military._duel_begin(); assert(battle.duel_pending)
		var type: int = caster.unit; var owner: int = caster.owner
		match property:
			"flagship": caster.unit = 52
			"dying": caster.die_t = 0
			"attached": caster.attached = true
			"foreign": caster.owner = enemy.owner
			"stale": battle.selected = [caster.duplicate(true)]
		rejected()
		caster.unit = type; caster.owner = owner; caster.die_t = -1; caster.attached = false
		battle.selected = [caster]
	# A carried target is not present on the battlefield, and a flagship refuses.
	for property in ["attached","flagship","range"]:
		battle.commands.military._duel_begin(); assert(battle.duel_pending)
		var type: int = enemy.unit; var x: float = enemy.ax
		match property:
			"attached": enemy.attached = true
			"flagship": enemy.unit = 52
			"range": enemy.ax = caster.ax + battle.tile_w * 11
		refresh()
		if property == "range": assert(is_same(battle.commands.orders._enemy_at(point()),enemy))
		rejected()
		enemy.unit = type; enemy.ax = x; enemy.attached = false; refresh()
	for property in ["flagship","dying","attached"]:
		battle.commands.orders._clear_pending()
		var type: int = caster.unit
		if property == "flagship": caster.unit = 52
		elif property == "dying": caster.die_t = 0
		else: caster.attached = true
		battle.commands.military._duel_begin(); assert(not battle.duel_pending)
		caster.unit = type; caster.die_t = -1; caster.attached = false
	print("DUEL VALIDITY PASS resolve-time caster identity-owner-life / flagship both sides / carried target / ten-cell range / no RNG on rejection")
	# Confirmed acceptance uses force difference and force squared, not staminaA.
	battle.simulation_rng.seed=81; var unchanged:int = battle.simulation_rng.randi(); battle.simulation_rng.seed=81
	assert(battle.commands.military._duel_accept(100, 1, 100, 50) and battle.simulation_rng.randi() == unchanged)
	# Equal stamina60, forceA50: the 20% branch accepts, then two damage rolls.
	caster.officer.might = 60; caster.officer.level = 0; caster.officer.tier = 4
	enemy.officer.might = 60; enemy.officer.level = 0; enemy.officer.tier = 4
	caster.hp = caster.maxhp * 0.5; enemy.hp = enemy.maxhp
	enemy.ax = caster.ax + battle.tile_w * 10; refresh()
	assert(is_same(battle.commands.orders._enemy_at(point()),enemy))
	var chosen := -1; var roll_a := 0; var roll_b := 0
	for value in range(100):
		battle.simulation_rng.seed=value
		if battle.simulation_rng.randi() % 5 != 2: continue
		roll_a = battle.simulation_rng.randi() % 5 + 4; roll_b = battle.simulation_rng.randi() % 5 + 4
		if roll_a != roll_b: chosen = value; break
	assert(chosen >= 0 and battle.commands.military._stamina_of(caster) == 60 and battle.commands.military._stamina_of(enemy) == 60)
	battle.cmd_pending = "move"; battle.jimou_pending = 0
	battle.commands.military._duel_begin()
	assert(battle.cmd_pending == "" and battle.jimou_pending == -1 and battle.duel_pending)
	battle.simulation_rng.seed=chosen; battle.commands.military._duel_at(point())
	assert(not battle.duel_pending)
	assert(paused and battle.view.event_view.active)
	assert(caster.hp == caster.maxhp * 0.5 and enemy.hp == enemy.maxhp)
	assert(battle.view.event_view.player.stream.resource_path.ends_with("LDAN.AVI") and battle.view.event_view.segments==[[24.0,38.0],[78.0,87.0]])
	battle.view.event_view.player.finished.emit()
	assert(not paused and not battle.view.event_view.active)
	assert(caster.hp == caster.maxhp * (50 - roll_b * 5) / 100.0)
	assert(enemy.hp == enemy.maxhp * (100 - int(roll_a * 2.5)) / 100.0)
	var resolved := [caster.hp, enemy.hp]
	battle.view.event_view._finish_media()
	assert([caster.hp, enemy.hp] == resolved)
	# Duplicate dispatch of the same click cannot damage again or draw randomness.
	rejected()
	print("DUEL ROUND PASS seeded20percent acceptance / damage crosses to opponent / one confirmation one round / other pending modes cleared")
	# Restoring a world during playback cancels the old callback and unpauses.
	var caster_id: int=caster.uid;var enemy_id: int=enemy.uid
	caster.hp=caster.maxhp*0.5;enemy.hp=enemy.maxhp
	assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
	var snapshot: Dictionary=game.load_save()
	battle.commands.military._duel_begin();battle.simulation_rng.seed=chosen;battle.commands.military._duel_at(point());assert(paused)
	assert(battle.saver.apply_snapshot(snapshot))
	assert(not paused and not battle.view.event_view.active)
	caster=battle.units.filter(func(u):return int(u.uid)==caster_id)[0]
	enemy=battle.units.filter(func(u):return int(u.uid)==enemy_id)[0]
	battle.selected=[caster];refresh()
	battle.view.event_view._finish_media()
	assert(caster.hp==caster.maxhp*0.5 and enemy.hp==enemy.maxhp)
	# Guaranteed victory with stamina120 versus1. The loser releases its surviving members.
	caster.officer.might = 100; caster.officer.level = 9; caster.officer.tier = 1
	enemy.officer.might = 1; enemy.officer.level = 0; enemy.officer.tier = 4
	caster.hp = caster.maxhp; enemy.hp = enemy.maxhp
	var members: Array = battle.units.filter(func(u): return u.owner == enemy.owner and int(u.get("group_officer",-1)) == int(enemy.officer.index))
	assert(not members.is_empty())
	var uid: int = enemy.uid
	battle.commands.military._duel_begin(); battle.simulation_rng.seed=17; battle.commands.military._duel_at(point())
	assert(paused and caster.hp == caster.maxhp and enemy.hp == enemy.maxhp)
	assert(battle.view.event_view.player.stream.resource_path.ends_with("LDAN.AVI") and battle.view.event_view.segments.size()==3)
	assert(not str(battle.view.event_view.caption.text).contains("胜出"))
	assert(str(battle.view.event_view.ending_caption).contains(str(caster.officer.name).replace(" ","")+"胜出"))
	var skip := InputEventKey.new(); skip.keycode = KEY_ESCAPE; skip.pressed = true
	battle.view.event_view._input(skip)
	assert(not paused)
	assert(caster.hp == caster.maxhp * 0.9 and enemy.hp == 0 and enemy.die_t >= 0)
	assert(members.all(func(u): return u.alive and u.group_officer == -1))
	battle.commands.military._die_step(enemy,10.0); battle.commands.world._prune_dead()
	assert(battle.units.all(func(u): return int(u.uid) != uid))
	assert(game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra()))
	assert(battle.saver.apply_snapshot(game.load_save()))
	assert(battle.units.all(func(u): return int(u.uid) != uid))
	print("DUEL VICTORY PASS winner90percent / loser removed / surviving members released / no resurrection on load")
	# A player defeat names the actual enemy victor and applies the inverse result.
	caster=battle.units.filter(func(u):return int(u.uid)==caster_id)[0]
	enemy=battle.units.filter(func(u):return u.owner!=battle.player_owner and not u.get("officer",{}).is_empty())[0]
	caster.officer.might=1;caster.officer.level=0;caster.officer.tier=4
	enemy.officer.might=100;enemy.officer.level=9;enemy.officer.tier=1
	caster.hp=caster.maxhp;enemy.hp=enemy.maxhp
	enemy.ax=caster.ax+88;enemy.ay=caster.ay;caster.vision=20
	battle.selected=[caster];refresh()
	for value in range(100):
		battle.simulation_rng.seed=value
		if battle.simulation_rng.randi()%5==2:chosen=value;break
	battle.commands.military._duel_begin();battle.simulation_rng.seed=chosen;battle.commands.military._duel_at(point())
	assert(paused and caster.hp==caster.maxhp)
	assert(battle.view.event_view.ending_caption.contains(str(enemy.officer.name).replace(" ","")+"胜出"))
	battle.view.event_view.player.finished.emit()
	assert(not paused and caster.hp==0 and enemy.hp==enemy.maxhp*0.9)
	print("DUEL CINEMATIC PASS win-loss-draw / original film / deferred HP / natural finish and skip / one settlement / restore cancels old callback")
	battle.free(); done = true; quit()
