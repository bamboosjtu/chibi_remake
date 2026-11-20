extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game: Node = root.get_node("Game")
	game.current_map = "chibil1"
	var battle := make_duel()
	var caster: Dictionary = battle.selected[0]
	var enemy: Dictionary = enemy_officer(battle)
	var caster_uid: int = caster.uid
	var enemy_uid: int = enemy.uid
	execute_duel(battle, enemy)
	var digest: Dictionary = preload("res://simulation/diagnostics/state_digest.gd").sections(battle, game)
	assert(paused and battle.view.event_view.active)
	assert(game.save_game(battle.units,battle.world.economy.player_resources(),battle.scene_controller._save_extra(),3),"Raw save must contain settled damage")
	var rng: int = battle.simulation_rng.state
	assert(battle.session_actions.save_game(3))
	var settled := [caster.hp,enemy.hp]
	assert(settled == [caster.maxhp*0.9,0.0])
	battle.view.event_view._finish_media()
	assert([caster.hp,enemy.hp] == settled,"Natural finish cannot settle twice")
	assert(battle.session_actions.load_slot(3).ok)
	var a: Dictionary = battle.units.filter(func(u):return int(u.uid)==caster_uid)[0]
	var b: Dictionary = battle.units.filter(func(u):return int(u.uid)==enemy_uid)[0]
	assert([a.hp,b.hp] == settled and battle.simulation_rng.state == rng)
	battle.free()
	var silent := make_duel()
	silent.world.effects.duel_requested.disconnect(silent._on_duel)
	execute_duel(silent, enemy_officer(silent))
	assert(not paused and silent.simulation_rng.state == rng)
	assert(preload("res://simulation/diagnostics/state_digest.gd").sections(silent, game) == digest)
	silent.free()
	print("DUEL SAVE PASS raw and session saves contain settled result / film completes once / restored HP and RNG")
	quit()

func make_duel() -> Node2D:
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false); battle.cli_mode = true; battle.ai = null
	battle.view.event_view.restore_history()
	var caster: Dictionary = battle.selected[0]
	var enemy := enemy_officer(battle)
	caster.officer.might = 100; caster.officer.level = 9; caster.officer.tier = 1
	enemy.officer.might = 1; enemy.officer.level = 0; enemy.officer.tier = 4
	enemy.ax = caster.ax + 88; enemy.ay = caster.ay; caster.vision = 20
	battle.visibility.update(battle.units,battle.player_owner)
	return battle

func enemy_officer(battle: Node2D) -> Dictionary:
	return battle.units.filter(func(u): return u.owner != battle.player_owner and not u.get("officer", {}).is_empty())[0]

func execute_duel(battle: Node2D, enemy: Dictionary) -> void:
	var hp: float = enemy.hp
	battle.actions.begin_target("duel")
	assert(battle.actions.submit_point_order(Vector2(enemy.ax, enemy.ay - enemy.h * 0.5), false) == 1)
	assert(enemy.hp == hp and battle.player_commands.has_pending())
	battle.world.battle_simulation._sim_step(battle.SIM_DT)
