extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var battle = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	var original: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	var state_id: int = battle.state.get_instance_id()
	var cases := []
	for ended in [-1,3,1.5,"1",null]:
		var bad := original.duplicate(true); bad.gameEnd=ended; cases.append(bad)
	for next in [-1,0.5,2147483648,1e100,"10",null]:
		var bad := original.duplicate(true); bad.nextUid=next; cases.append(bad)
	for record in original.units:
		var bad := original.duplicate(true)
		var index: int = original.units.find(record)
		bad.units[index].building=not bool(record.building); cases.append(bad)
	var bad := original.duplicate(true); bad.units[0].state="typo-new-state"; cases.append(bad)
	for field in ["uid","unit","owner"]:
		bad=original.duplicate(true); bad.units[0][field]=1e100; cases.append(bad)
	for field in ["x","y"]:
		bad=original.duplicate(true); bad.units[0][field]=1e100; cases.append(bad)
	bad=original.duplicate(true); bad.units[0].simulation.path=[[1e100,0]]; cases.append(bad)
	bad=original.duplicate(true); bad.units[0].simulation.repathTo=[0,1e100]; cases.append(bad)
	for invalid in cases:
		invalid.erase("checksum"); invalid.checksum=game.save_checksum(invalid)
		assert(game.verify_save_checksum(invalid))
		assert(not game.is_valid_save(invalid) and not game.can_rotate_save(invalid))
		assert(not battle.saver.apply_snapshot(invalid))
		assert(battle.state.get_instance_id()==state_id and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	for ended in [0,1,2]:
		var valid := original.duplicate(true); valid.gameEnd=ended; valid.erase("checksum")
		valid.checksum=game.save_checksum(valid)
		assert(game.is_valid_save(valid) and battle.saver.apply_snapshot(valid))
	var schema = load("res://simulation/units/unit_schema.gd")
	for state in schema.FIELDS.state.values:
		assert(schema.valid_value("state",state))
	var boarded: Dictionary=original.units[0].duplicate(true);boarded.unit=47.0;boarded.building=false;boarded.state="boarded"
	assert(schema.valid_record(boarded))
	assert(battle.saver.apply_snapshot(original))
	battle.scene.ready_to_save=false; battle.free()
	print("SAVE SEMANTICS PASS correct-checksum rejection / building derived from unit / gameEnd enum / bounded nextUid / state catalog / atomic rejection")
	done=true; quit()
