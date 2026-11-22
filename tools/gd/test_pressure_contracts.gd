extends "test_contact_and_occupancy.gd"
func run() -> void:
	root.get_node("Game").current_map="chibic17"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true);metadata=scene.map_data.units.duplicate(true)
	var game: Node=root.get_node("Game")
	var saved: Dictionary=game.snapshot(scene.units,scene.world.economy.player_resources(),scene.scene_controller._save_extra())
	for i in range(30):scene.world.battle_simulation._sim_step(scene.SIM_DT)
	var expected: String=game.save_checksum(scene.saver.continuation_snapshot(game))
	assert(scene.saver.apply_snapshot(saved))
	scene.world.unit_actions.profile_enabled=true
	for i in range(30):scene.world.battle_simulation._sim_step(scene.SIM_DT)
	assert(game.save_checksum(scene.saver.continuation_snapshot(game))==expected,"Profiling changes domain state")
	assert(scene.world.unit_actions.profile.units>0 and scene.world.unit_actions.profile.action>0)
	scene.scene.ready_to_save=false;scene.free()
	blank();var actor:=make(1,3,32,Vector2i(10,10))
	for px in [484.0,483.99999,484.00001,0.0,1847.0]:
		for py in [16.5,16.49999,27.5,499.0]:
			actor.ax=px;actor.ay=py
			for i in range(2):assert(sim.world.spatial_index._unit_cell(actor)==sim.nav.cell_of_px(px,py))
	var map: Dictionary=sim.map_data.duplicate(true);map.tileW=88;sim.nav.setup(map)
	assert(sim.world.spatial_index._unit_cell(actor)==sim.nav.cell_of_px(actor.ax,actor.ay))
	sim.nav.tile_w=44;sim.nav.tile_hw=22;sim.nav.tile_hh=11
	assert(sim.world.spatial_index._unit_cell(actor)==sim.nav.cell_of_px(actor.ax,actor.ay))
	blank();var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(12,10));install([a,b])
	a.ax=484.0;sim.nav.block(Vector2i(11,10))
	var clear: bool=sim.world.combat._melee_line_clear(a,b)
	a.ax=483.99999
	var cached: bool=sim.world.combat._melee_line_clear(a,b)
	sim.world.combat._contact_cache.clear()
	assert(cached==sim.world.combat._melee_line_clear(a,b),"Sub-float32 endpoint movement reused a stale contact result")
	sim.free();sim=null;population_contract();done=true;print("PRESSURE CONTRACTS PASS profile equivalence / exact coordinate cache / setup and setter invalidation / contact precision");quit()

func population_contract() -> void:
	var rules_path: String=get_script().resource_path.get_base_dir().path_join("../../research/20-population/data/limits.json").simplify_path()
	var limits: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(rules_path)).limits
	assert(int(limits.entitySlotsPerSide)==200 and int(limits.heroSlotsPerSide)==20)
	for capacity in [true,false]:
		root.get_node("Game").current_map="chibic17"
		var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
		var fixture=load("res://testing/benchmark/full_battle_benchmark.gd").new()
		fixture.capacity_stress=capacity;fixture.target_units=660;fixture.engage=240
		fixture._fill(scene)
		var sides: Dictionary=fixture.population(scene)
		for owner in ["1","2","3"]:
			assert(sides[owner].entities==200 and sides[owner].mobile+sides[owner].buildings==200 and sides[owner].officers<=20)
		assert(fixture.engaged_actual==240)
		if capacity:assert(fixture.target_units==460 and not sides.has("4"))
		else:assert(fixture.target_units==660 and sides["4"].entities==200)
		fixture.free();scene.scene.ready_to_save=false;scene.free()
	print("POPULATION WORKLOAD PASS research limits / three configured sides / buildings consume slots / legacy fourth side retained")

