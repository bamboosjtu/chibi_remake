extends SceneTree
const K=preload("res://simulation/native/math_kernel.gd")
func _initialize():run.call_deferred()
func run():
	if K.get_kernel()==null:print("NATIVE WORLD FALLBACK PASS");quit();return
	root.get_node("Game").current_map="chibic17"
	var b=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false)
	var fixture=load("res://testing/full_battle_benchmark.gd").new();fixture.target_units=660;fixture.engage=240;fixture._fill(b);fixture.free()
	for u in b.units:u.hp=10000000.;u.maxhp=u.hp
	var game: Node=root.get_node("Game")
	var snapshot: Dictionary=game.snapshot(b.units,b.world.economy.player_resources(),b.scene_controller._save_extra())
	K.force_script=true
	var digests: Array=[]
	var expected_payloads: Array=[]
	for tick in range(60):
		b.world.battle_simulation._sim_step(b.SIM_DT)
		if tick%10==9:
			expected_payloads.append(b.saver.continuation_snapshot(game))
			digests.append(game.save_checksum(expected_payloads.back()))
	assert(b.saver.apply_snapshot(snapshot))
	# The benchmark deliberately overrides canonical HP; restoration normalizes it.
	# Reapply that identical workload override before comparing execution backends.
	for u in b.units:u.hp=10000000.;u.maxhp=u.hp
	K.force_script=false
	assert(b.world.battle_simulation.native_unit_port!=null,"Native batch port was not connected")
	b.world.battle_simulation.profile_enabled=true
	b.world.unit_actions.profile_enabled=true
	for tick in range(60):
		b.world.battle_simulation._sim_step(b.SIM_DT)
		if tick%10==9:
			var actual: String=game.save_checksum(b.saver.continuation_snapshot(game))
			if actual!=digests[tick/10]:
				var f:=FileAccess.open(OS.get_environment("LOCALAPPDATA").path_join("native-mismatch.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"expected":expected_payloads[tick/10],"actual":b.saver.continuation_snapshot(game)}));f.close()
				assert(false,"Native world mismatch tick "+str(tick))
	assert(int(b.world.battle_simulation.native_unit_profile.get("units",0))>0,"Native batch did not execute")
	b.scene.ready_to_save=false;b.free();print("NATIVE WORLD PASS 660 mobiles / six complete snapshots / script versus native ordered execution");quit()
