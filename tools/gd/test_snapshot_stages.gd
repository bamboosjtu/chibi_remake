extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var battle = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	var baseline: Dictionary = game.snapshot(battle.units,battle.commands.world._resources(),battle.saver.save_extra())
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	var state_id: int = battle.state.get_instance_id()
	var cases := []
	var invalid := baseline.duplicate(true); invalid.units.append(invalid.units[0].duplicate(true)); cases.append([invalid,"unit records"])
	invalid=baseline.duplicate(true); invalid.simulation.terrainChanges={"bad":true}; cases.append([invalid,"terrain"])
	invalid=baseline.duplicate(true); invalid.simulation.aiResources={"2":3}; cases.append([invalid,"owners/groups/officers"])
	invalid=baseline.duplicate(true); invalid.trainings=[{"buildingUid":2147483647,"unit":30,"owner":battle.player_owner,"t":0,"ticks":true,"cost":{}}]; cases.append([invalid,"production"])
	invalid=baseline.duplicate(true); invalid.simulation.playerTech={"level":-1}; cases.append([invalid,"technology/research"])
	invalid=baseline.duplicate(true); invalid.units[0].simulation.action_phase=999; cases.append([invalid,"unit simulation"])
	invalid=baseline.duplicate(true); invalid.simulation.speedIndex=99; cases.append([invalid,"world services/clock"])
	for fixture in cases:
		invalid=fixture[0]; invalid.erase("checksum"); invalid.checksum=game.save_checksum(invalid)
		assert(game.verify_save_checksum(invalid))
		assert(not battle.saver.apply_snapshot(invalid))
		assert(str(battle.saver.last_load_error).contains(fixture[1]), battle.saver.last_load_error)
		assert(battle.state.get_instance_id()==state_id and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	battle.scene.ready_to_save=false; battle.free()
	print("SNAPSHOT STAGES PASS seven independent rejection stages / correct checksums / live world retained")
	quit()
