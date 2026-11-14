extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game: Node = root.get_node("Game")
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false); battle.cli_mode = true; battle.ai = null
	battle.view.event_view.restore_history()
	var caster: Dictionary = battle.selected[0]
	var enemy: Dictionary = battle.units.filter(func(u):return u.owner!=battle.player_owner and not u.get("officer",{}).is_empty())[0]
	caster.officer.might = 100; caster.officer.level = 9; caster.officer.tier = 1
	enemy.officer.might = 1; enemy.officer.level = 0; enemy.officer.tier = 4
	enemy.ax = caster.ax + 88; enemy.ay = caster.ay; caster.vision = 20
	battle.visibility.update(battle.units,battle.player_owner)
	var caster_uid: int = caster.uid
	var enemy_uid: int = enemy.uid
	battle.commands.military._duel_begin()
	battle.commands.military._duel_at(Vector2(enemy.ax,enemy.ay-enemy.h*0.5))
	assert(paused and battle.view.event_view.active and battle.state.effects.pending_duels().size()==1)
	assert(not game.save_game(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra(),3),"Raw save must refuse unsettled results")
	var rng: int = battle.simulation_rng.state
	assert(battle.commands.session._save_game(3))
	var settled := [caster.hp,enemy.hp]
	assert(settled == [caster.maxhp*0.9,0.0] and battle.state.effects.pending_duels().is_empty())
	battle.view.event_view._finish_media()
	assert([caster.hp,enemy.hp] == settled,"Natural finish cannot settle twice")
	assert(battle.commands.session.load_slot(3).ok)
	var a: Dictionary = battle.units.filter(func(u):return int(u.uid)==caster_uid)[0]
	var b: Dictionary = battle.units.filter(func(u):return int(u.uid)==enemy_uid)[0]
	assert([a.hp,b.hp] == settled and battle.simulation_rng.state == rng)
	assert(battle.state.effects.pending_duels().is_empty())
	battle.free()
	print("DUEL SAVE PASS raw save refused / session saves commit pending result / film completes once / restored HP and RNG")
	quit()
