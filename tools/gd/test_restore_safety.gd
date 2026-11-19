extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(100).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game: Node = root.get_node("Game")
	game.startup_map_consumed = true; game.startup_load_consumed = true
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle); current_scene = battle; battle.set_process(false)
	assert(battle.scene.ready_to_save)
	var victim: Dictionary = battle.units.filter(func(u):return u.owner!=battle.player_owner and int(u.owner)>0 and not u.is_building)[0]
	var victim_id: int = victim.uid
	victim.hp = -12
	battle.world.combat._kill(victim)
	victim.die_t = 0.25
	assert(battle.saver.apply_snapshot(game.snapshot(battle.units,battle.world.economy.player_resources(),battle.scene_controller._save_extra())))
	victim = battle.units.filter(func(u):return int(u.uid)==victim_id)[0]
	assert(victim.alive and victim.hp == -12 and victim.die_t == 0.25,"Dying units must retain their remaining animation and exact HP")
	assert(battle.session_actions.save_game())
	var primary_hash := FileAccess.get_sha256(game.SAVE_PATH)
	var snapshot: Dictionary = game.load_save()
	var resources: Dictionary = battle.nav.state.resource_cells.duplicate()
	assert(not resources.is_empty())
	assert(battle.session_actions.load_slot(0).ok)
	assert(battle.nav.state.resource_cells == resources,"Forest blockers must survive restore")
	var resource: Dictionary = battle.decor_targets.filter(func(d):return bool(d.alive))[0]
	battle.world.harvest_orders._remove_decor(resource)
	resources = battle.nav.state.resource_cells.duplicate()
	assert(battle.session_actions.save_game(2))
	assert(battle.session_actions.load_slot(2).ok)
	assert(battle.nav.state.resource_cells == resources,"Depleted cells must remain walkable")
	var invalid := snapshot.duplicate(true)
	invalid.simulation.contentRevision = "retired-build"
	invalid.erase("checksum"); invalid.checksum = game.save_checksum(invalid)
	assert(game.Store.commit(game.save_slot_path(1),JSON.stringify(invalid),game.verify_save_checksum))
	var state_id: int = battle.state.get_instance_id()
	var rejected: Dictionary = battle.session_actions.load_slot(1)
	assert(not rejected.ok and not str(rejected.error).is_empty())
	assert(battle.state.get_instance_id() == state_id)
	invalid.map = "chibil2"; invalid.erase("checksum"); invalid.checksum = game.save_checksum(invalid)
	assert(game.Store.commit(game.save_slot_path(1),JSON.stringify(invalid),game.verify_save_checksum))
	rejected = battle.session_actions.load_slot(1)
	assert(not rejected.ok and current_scene == battle and battle.state.get_instance_id() == state_id)
	assert(game.current_map == "chibil1" and FileAccess.get_sha256(game.SAVE_PATH) == primary_hash)
	# Start a rejected load, then try every save command before its deferred return.
	battle.free(); game.current_map = "chibil2"; game.pending_load = true; game.pending_load_slot = 1
	game.startup_map_consumed = false; game.startup_load_consumed = false
	var failed = load("res://main.tscn").instantiate()
	root.add_child(failed); current_scene = failed
	assert(not failed.scene.ready_to_save and not failed.is_processing())
	assert(not failed.session_actions.save_game())
	assert(FileAccess.get_sha256(game.SAVE_PATH) == primary_hash)
	await process_frame; await process_frame
	assert(current_scene.scene_file_path == "res://menu.tscn")
	assert(FileAccess.get_sha256(game.SAVE_PATH) == primary_hash)
	print("RESTORE SAFETY PASS forest blockers / depletion / same and cross-map rejection / deferred menu / no automatic overwrite")
	done = true; quit()
