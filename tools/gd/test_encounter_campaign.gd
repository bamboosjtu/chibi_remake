extends SceneTree
const Engagement = preload("res://simulation/combat/engagement.gd")
var b: Node2D
var done := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game := root.get_node("Game"); game.current_map = "chibil1"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	var hero: Dictionary = b.selected[0]
	var workers: Array = b.units.filter(func(u): return int(u.owner)==int(hero.owner) and int(u.get("group_officer",-1))==int(hero.officer.index))
	var enemy: Dictionary = b.units.filter(func(u): return int(u.owner)!=int(hero.owner) and int(u.owner)!=0 and not bool(u.is_building))[0]
	var origin := Vector2(hero.ax, hero.ay)
	enemy.ax=origin.x+100; enemy.ay=origin.y; enemy.vision=8
	for u in [hero, enemy]+workers: b.world.command_groups._cancel_unit_command(u)
	b.visibility.update(b.units,b.player_owner)
	b.sim_tick = (6-int(hero.uid)%6)%6
	b.world.unit_actions._step_unit(hero,b.SIM_DT)
	assert(hero.state=="attack" and is_same(hero.target,enemy))
	assert(workers.all(func(u):return u.state=="attack" and is_same(u.target,enemy)))
	# The first chapter has no enemy production building; local combat still starts.
	b.sim_tick = (6-int(enemy.uid)%6)%6
	b.world.unit_actions._step_unit(enemy,b.SIM_DT)
	assert(enemy.state=="attack" and int(enemy.target.owner)==b.player_owner)
	hero.hp=100000;hero.maxhp=100000;enemy.hp=100000;enemy.maxhp=100000
	for tick in range(200):b.world.battle_simulation._sim_step(b.SIM_DT)
	assert(enemy.hp<100000 or hero.hp<100000,"encounters must produce real battle damage")
	for state in ["move","gather","deliver","build","repair","rest","board"]:
		b.world.command_groups._cancel_unit_command(hero); hero.state=state
		Engagement.step(b.state,hero,b.world.combat._nearest_enemy); assert(hero.state==state and hero.target==null)
	b.world.command_groups._cancel_unit_command(hero); hero.hold=true; Engagement.step(b.state,hero,b.world.combat._nearest_enemy); assert(hero.state=="idle")
	hero.hold=false;hero.carry=200;Engagement.step(b.state,hero,b.world.combat._nearest_enemy);assert(hero.state=="idle");hero.carry=0
	# Ambush is not stealth: idle encounters still acquire these visible enemies.
	for u in b.units:
		if int(u.owner)!=b.player_owner and int(u.owner)!=0:u.ambush_t=10
	b.sim_tick = (6-int(hero.uid)%6)%6
	Engagement.step(b.state,hero,b.world.combat._nearest_enemy);assert(hero.state=="attack" and int(hero.target.owner)!=0)
	print("ENCOUNTER PASS both armies / chapter-one camp / idle worker cohort / preserve explicit work-march-hold / ambush remains targetable / no neutral target")
	assert(game.next_level("chibil1").map=="chibil2")
	assert(game.next_level("chibil6").map=="chibil7a")
	assert(game.next_level("chibil7a").map=="chibil7b")
	assert(game.next_level("chibil7b").map=="chibil8")
	assert(game.next_level("chibic16").map=="chibic17")
	assert(game.next_level("chibil16").is_empty() and game.next_level("chibic17").is_empty())
	assert(game.next_level("unknown").is_empty())
	var flow = b.view.completion
	flow.automatic = true
	b.cli_mode = false
	b.map_id = "chibil16"
	b.view.show_end(1)
	assert(flow.panel.visible and b.view.end_label.visible and paused, "campaign finale keeps its end panel")
	flow.reset()
	b.map_id = "chibil1"
	b.view.show_end(2)
	assert(flow.panel.visible and b.view.end_label.visible and paused, "defeat keeps its end panel")
	flow.reset()
	b.view.end_label.hide()
	current_scene = b
	game.pending_load = true
	game.pending_load_slot = 1
	for unit in b.units:
		if int(unit.owner) != b.player_owner and int(unit.owner) != 0:
			unit.alive = is_same(unit, enemy)
	enemy.die_t = -1.0
	b.world.campaign._check_end()
	assert(b.game_end == 0 and not flow.panel.visible and not b.view.end_label.visible, "surviving enemy prevents transition")
	enemy.alive = false
	b.world.campaign._check_end()
	assert(b.game_end == 1 and not flow.panel.visible and not b.view.end_label.visible and paused, "normal victory queues a silent transition")
	var tick: int = b.sim_tick
	b.world.battle_simulation._sim_step(b.SIM_DT)
	assert(b.sim_tick == tick)
	await process_frame;await process_frame;await process_frame
	b=current_scene
	assert(b!=null and b.map_id=="chibil2" and game.current_map=="chibil2")
	assert(not paused and not game.pending_load and game.pending_load_slot==0 and b.game_end==0)
	b.set_process(false);b.cli_mode=true
	assert(b.gold==float(b.map_data.scenario.sides[0].resources[0]))
	print("CAMPAIGN ADVANCE PASS 34-chapter ordering / Liu7a7b / terminal campaigns / last enemy blocks victory / finale and defeat panels / direct scene switch / fresh next world")
	done=true;quit()
