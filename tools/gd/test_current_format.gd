extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node=root.get_node("Game")
	var battle=load("res://main.tscn").instantiate();root.add_child(battle);battle.set_process(false)
	var current: Dictionary=game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	assert(int(current.v)==9 and game.is_valid_save(current))
	assert(not battle.saver.has_method("restore_legacy") and not preload("res://app/saves/rules_identity.gd").new().has_method("approved_migration"))
	var identity: int=battle.state.get_instance_id()
	var before: String=game.save_checksum(battle.saver.continuation_snapshot(game))
	var stock_presence: Dictionary={}
	for unit in battle.units: stock_presence[int(unit.uid)] = unit.has("stock")
	for version in range(1,9):
		var retired: Dictionary=current.duplicate(true);retired.v=version
		retired.erase("checksum");retired.checksum=game.save_checksum(retired)
		assert(not game.is_valid_save(retired) and not game.can_rotate_save(retired))
		assert(not battle.saver.apply_snapshot(retired))
		assert(battle.state.get_instance_id()==identity and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	for field in ["rulesRevision","contentRevision"]:
		var invalid: Dictionary=current.duplicate(true);invalid.simulation[field]="retired-or-unknown"
		assert(not battle.saver.apply_snapshot(invalid))
		invalid.simulation.erase(field);assert(not battle.saver.apply_snapshot(invalid))
	var unverified: Dictionary=current.duplicate(true);unverified.erase("checksum")
	assert(not game.is_valid_save(unverified))
	assert(battle.world.entity_factory._spawn_unit(32,battle.player_owner,1500,1500,true))
	assert(battle.saver.apply_snapshot(current))
	for unit in battle.units: assert(unit.has("stock")==stock_presence[int(unit.uid)],"Optional resource capability must preserve presence")
	assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	battle.scene.ready_to_save=false;battle.free()
	_verify_head_fixtures(game)
	print("CURRENT FORMAT PASS v9 only / retired versions rejected / exact rule and map identity / checksum required / isolated replacement")
	quit()

func _verify_head_fixtures(game: Node) -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join("../inputs/save-v9-7ddf81a.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary and data.fixtures.size() == 2)
	game.current_map = "chibic1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	battle.set_process(false)
	for fixture in data.fixtures:
		var raw := Marshalls.base64_to_raw(fixture.gzip).decompress(int(fixture.length), FileAccess.COMPRESSION_GZIP)
		var text := raw.get_string_from_utf8()
		assert(text.sha256_text() == fixture.sha256)
		var snapshot = JSON.parse_string(text)
		assert(game.is_valid_save(snapshot))
		var slot := 20 if fixture.map == "chibic1" else 19
		var slot_path: String = game.save_slot_path(slot)
		if slot == 19: slot_path += ".bak"
		assert(game.Store.commit(slot_path, text, game.is_valid_save))
		if slot == 19 and battle.view != null:
			var epoch: int = battle.world.get_instance_id()
			var position: Vector2 = battle.cam.position
			var zoom: Vector2 = battle.cam.zoom
			var terrain: Node2D = battle.view.world_layers.terrain
			var swap: Script = load("res://app/saves/world_transaction.gd")
			swap.force_view_failure_after_attach = true
			var rejected: Dictionary = battle.session_actions.load_slot(slot)
			swap.force_view_failure_after_attach = false
			assert(not rejected.ok and battle.world.get_instance_id() == epoch)
			assert(battle.view.world_layers.terrain == terrain and is_instance_valid(terrain))
			assert(battle.cam.position == position and battle.cam.zoom == zoom)
		var result: Dictionary = battle.session_actions.load_slot(slot)
		assert(result.ok and result.cross_map == (slot == 19))
		assert(result.source == ("backup" if slot == 19 else "primary"))
		assert(current_scene == battle and battle.map_id == fixture.map and game.current_map == fixture.map)
		var current_map: Dictionary = battle.world.definition
		var opening := str(current_map.scenario.avi)
		assert(opening.ends_with(".mp4"), "Runtime must retain the canonical HD opening")
		assert(battle.saver.content_revision() == snapshot.simulation.contentRevision)
		assert(current_map.scenario.avi == opening, "Save identity projection must not mutate the runtime opening")
		var unrelated: Dictionary = current_map.duplicate(true)
		unrelated.scenario.avi = "custom.mp4"
		var projected: Dictionary = battle.saver._map_projection(unrelated)
		assert(projected.scenario.avi == "custom.mp4", "Only recognized campaign replacements keep the old identity")
		assert(game.save_checksum(battle.saver.continuation_snapshot(game)) == fixture.at31)
		for tick in range(7): battle.world.battle_simulation._sim_step(battle.SIM_DT)
		assert(game.save_checksum(battle.saver.continuation_snapshot(game)) == fixture.at38)
	battle.free()
	print("HEAD V9 FIXTURES PASS same map / cross map / backup / seven tick continuation")
