extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var canonical_fixture := {"z":[null,true,false,1,1.0], "a":{"2":"quoted \"text\"", "10":"中文"}}
	assert(game.save_canonical_text(canonical_fixture) == '{"a":{"10":"中文","2":"quoted \\"text\\""},"z":[null,true,false,1,1]}', "Canonical v9 bytes must retain recursive lexical ordering, escaping and integer normalization")
	assert(game.save_canonical_text({2:"two",10:"ten"}) == '{"10":"ten","2":"two"}', "Integer dictionary keys retain string ordering")
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false)
	var good: Dictionary = game.snapshot(battle.units, battle.commands.world._resources(), battle.saver.save_extra())
	assert(game.verify_save_checksum(good) and game.is_valid_save(good))
	_required_fields(game, battle)
	var empty_world := good.duplicate(true); empty_world.units=[]; empty_world.erase("checksum")
	empty_world.checksum=game.save_checksum(empty_world)
	assert(game.is_valid_save(empty_world), "Modern snapshots may contain an empty terminal world")
	var legacy := good.duplicate(true); legacy.v=7; legacy.erase("checksum")
	assert(not game.is_valid_save(legacy) and not game.verify_save_checksum(legacy) and not game.can_rotate_save(legacy))
	for invalid in [{"v":7}, {"checksum":"wrong"}, {"v":"7"}, {"v":-1}, {"v":10}, {"v":7.5}]:
		assert(not game.is_valid_save(invalid))
	var malformed := good.duplicate(true); malformed.units[0].uid="bad"
	malformed.erase("checksum"); malformed.checksum=game.save_checksum(malformed)
	assert(game.verify_save_checksum(malformed) and not game.is_valid_save(malformed))
	var invalid_path := good.duplicate(true); invalid_path.units[0].simulation.path=[[{},0]]
	invalid_path.erase("checksum"); invalid_path.checksum=game.save_checksum(invalid_path)
	assert(not game.is_valid_save(invalid_path) and not game.can_rotate_save(invalid_path))
	assert(not battle.saver.apply_snapshot(invalid_path), "Reject path coordinate types before restoration")
	for invalid_reference in [{"repathTo":null},{"targetUid":"bad"},{"gatherRef":null}]:
		assert(not preload("res://simulation/definitions/unit_schema.gd").valid_snapshot(invalid_reference))
	var spent: Dictionary=good.units[0].simulation.duplicate(true)
	spent.gatherRef={"kind":"spent","unit":24.0,"x":1,"y":2}
	assert(preload("res://simulation/definitions/unit_schema.gd").valid_snapshot(spent), "JSON integer-valued floats must preserve spent sources")
	spent.gatherRef.unit=24.5
	assert(not preload("res://simulation/definitions/unit_schema.gd").valid_snapshot(spent))
	var path: String = game.SAVE_PATH.get_base_dir().path_join("validity.json")
	var store = preload("res://app/json_store.gd")
	assert(store.commit(path,JSON.stringify(good),game.is_valid_save,game.can_rotate_save))
	assert(store.commit(path,JSON.stringify(good),game.is_valid_save,game.can_rotate_save))
	var backup_hash := FileAccess.get_sha256(path+".bak")
	for damaged in [{"v":7}, legacy, malformed]:
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(damaged)); file.close()
		store.force_commit_failure=true
		assert(not store.commit(path,JSON.stringify(good),game.is_valid_save,game.can_rotate_save))
		assert(FileAccess.get_sha256(path+".bak")==backup_hash,"Last verified backup was overwritten")
		assert(store.read(path,game.is_valid_save)==good,"Backup must remain readable after failed commit")
	assert(store.commit(path,JSON.stringify(good),game.is_valid_save,game.can_rotate_save))
	assert(game.is_valid_save(store.read(path,game.is_valid_save)))
	battle.scene.ready_to_save=false; battle.free()
	print("SAVE VALIDITY PASS checksum separate from structure / retired formats rejected / failed rotation preserves verified backup")
	done=true; quit()

func _required_fields(game: Node, battle: Node2D) -> void:
	var hq: Dictionary = battle.units.filter(func(unit): return int(unit.owner) == battle.player_owner and int(unit.unit) in [0,1])[0]
	assert(battle.commands.economy._queue_train(battle.player_owner, hq, 30))
	var complete: Dictionary = game.snapshot(battle.units, battle.commands.world._resources(), battle.saver.save_extra())
	assert(not complete.trainings.is_empty())
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	var state_id: int = battle.state.get_instance_id()
	var cases: Array = []
	for key in ["resources", "trainings"]:
		var missing := complete.duplicate(true); missing.erase(key); cases.append(missing)
	for key in ["gold", "wood", "food", "stone"]:
		var missing := complete.duplicate(true); missing.resources.erase(key); cases.append(missing)
	for value in [null, {}, "invalid"]:
		var invalid := complete.duplicate(true); invalid.trainings=value; cases.append(invalid)
	for invalid in cases:
		invalid.erase("checksum"); invalid.checksum=game.save_checksum(invalid)
		assert(game.verify_save_checksum(invalid), "Failure fixture must have a correct checksum")
		assert(not game.is_valid_save(invalid) and not game.can_rotate_save(invalid))
		assert(not battle.saver.apply_snapshot(invalid))
		assert(battle.state.get_instance_id() == state_id)
		assert(game.save_checksum(battle.saver.continuation_snapshot(game)) == before, "Rejected v8 changed resources or production")
		var path: String = game.SAVE_PATH.get_base_dir().path_join("incomplete-v8.json")
		assert(game.Store.commit(path, JSON.stringify(invalid), game.verify_save_checksum))
		assert(game.Store.read(path, game.is_valid_save).is_empty())
	assert(battle.saver.apply_snapshot(complete))
	assert(game.save_checksum(battle.saver.continuation_snapshot(game)) == before)
	print("CURRENT REQUIRED FIELDS PASS correct checksum / every resource required / queue required / atomic rejection")
