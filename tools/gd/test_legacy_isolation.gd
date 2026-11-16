extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(240).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	var game: Node=root.get_node("Game");game.current_map="chibic1"
	var b=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false);b.cli_mode=true
	var archive: Dictionary=game.snapshot(b.units,b.commands.world._resources(),b.commands.session._save_extra())
	archive.v=3;archive.erase("simulation");archive.erase("checksum")
	archive=JSON.parse_string(JSON.stringify(archive))
	var expected_count: int=archive.units.size()
	assert(b.saver.apply_snapshot(archive),"Clean/menu-equivalent v3 load")
	var expected: String=game.save_checksum(b.saver.continuation_snapshot(game))
	assert(b.commands.world._spawn_unit(32,3,1500,1500,true))
	var extra: int=b.units.back().uid
	b.fire_fields.active=[{"a":10,"b":10,"age":4}]
	b.task_latches={"current-world-only":true};b.player_tech.level=3;b.simulation_rng.randi()
	b.ai._assault[2]=65;b.ai_res[2]={"gold":1,"wood":1,"food":1,"stone":1}
	assert(b.saver.apply_snapshot(archive),"v3 load from a running battle")
	assert(b.units.size()==expected_count and b.units.all(func(u):return int(u.uid)!=extra))
	assert(b.fire_fields.active.is_empty() and b.projectiles.active.is_empty())
	assert(game.save_checksum(b.saver.continuation_snapshot(game))==expected,"Legacy result must not depend on current world")
	var corrupt: Dictionary=archive.duplicate(true);corrupt.units.append(corrupt.units[0].duplicate(true))
	assert(not b.saver.apply_snapshot(corrupt))
	assert(game.save_checksum(b.saver.continuation_snapshot(game))==expected,"Rejected migration keeps the live battle")
	corrupt=archive.duplicate(true);corrupt.units[0].x={"bad":true}
	assert(not b.saver.apply_snapshot(corrupt) and game.save_checksum(b.saver.continuation_snapshot(game))==expected)
	print("LEGACY ISOLATION PASS v3 clean/running equivalence / dynamic units and fire cleared / RNG AI tasks reset / atomic rejection")
	for version in [1,2]:
		var older: Dictionary=archive.duplicate(true);older.v=version;older.units=[]
		for record in archive.units:
			if version==1:older.units.append([1 if record.alive else 0,record.x,record.y,record.hp])
			else:older.units.append([record.uid,1 if record.alive else 0,record.x,record.y,record.hp,record.owner,record.unit,0,record.mapObject,record.mapIndex])
		if version==2:older.units.append([500,1,1500,1500,100,3,32,0,false,-1])
		assert(b.saver.apply_snapshot(older),"Older format "+str(version))
		var clean: String=game.save_checksum(b.saver.continuation_snapshot(game))
		assert(b.commands.world._spawn_unit(32,3,1700,1500,true))
		b.fire_fields.active=[{"a":12,"b":12,"age":8}]
		assert(b.saver.apply_snapshot(older) and game.save_checksum(b.saver.continuation_snapshot(game))==clean)
		if version==2:assert(b.next_uid>500)
	assert(b.saver.apply_snapshot(archive))
	expected=game.save_checksum(b.saver.continuation_snapshot(game))
	print("LEGACY DEFAULTS PASS v1/v2 independent seeds / known commander identity / sparse UID allocation")
	var Identity=load("res://app/saves/rules_identity.gd")
	assert(Identity.catalog_hash("{\"a\":1,\"b\":[2]}") == Identity.catalog_hash("{\r\n\"b\":[2],\r\n\"a\":1\r\n}"),"Rule fingerprints ignore formatting and platform newlines")
	var records := {}
	for file in ["unit_definitions.json","production_units.json","buildings.json","scenario_rules.json"]:records[file]=FileAccess.get_sha256("res://data/db/"+file)
	var fingerprint: String=Identity.fingerprint(records)
	for file in records:
		var changed:=records.duplicate();changed[file]="different"
		assert(Identity.fingerprint(changed)!=fingerprint,"Omitted effective rules input: "+file)
	var current: Dictionary=game.snapshot(b.units,b.commands.world._resources(),b.commands.session._save_extra())
	assert(str(current.simulation.rulesRevision).length()==64)
	var scoped: Dictionary=current.duplicate(true)
	scoped.simulation.rulesRevision="f9634e5c4bd01f214f81f529305570acc6e3550dec159515d93bae178d123d1f"
	assert(b.saver.apply_snapshot(scoped),"Pinned prior wide fingerprint migration")
	var bad: Dictionary=current.duplicate(true);bad.simulation.rulesRevision="wrong"
	assert(not b.saver.apply_snapshot(bad))
	assert(game.save_checksum(b.saver.continuation_snapshot(game))==expected)
	current.simulation.erase("rulesRevision");current.simulation.erase("rulesPolicy")
	current.simulation.contentRevision=b.saver._map_revision(str(Identity.legacy_scenario_hashes()[0]))
	var legacy_worker: Dictionary=current.units.filter(func(u):return int(u.unit)==32)[0]
	legacy_worker.simulation.base_maxhp=999;legacy_worker.simulation.maxhp=999
	legacy_worker.simulation.erase("tech_hp_bonus")
	var saved_hp: float=legacy_worker.hp
	current=JSON.parse_string(JSON.stringify(current))
	b.player_tech.level=3
	b.army_tech[2]=load("res://simulation/systems/technology_state.gd").initial();b.army_tech[2].level=3
	assert(b.saver.apply_snapshot(current),"Known unversioned v8 rules explicitly adopt current rules")
	var migrated: Dictionary=b.units.filter(func(u):return int(u.uid)==int(legacy_worker.uid))[0]
	assert(migrated.base_maxhp==b.map_data.units["32"].hp and migrated.maxhp==b.map_data.units["32"].hp and migrated.hp==saved_hp,"Legacy derived rule caches/live technology must not override current data or saved HP")
	print("RULES IDENTITY PASS complete data inputs / strict fingerprint rejection / explicit legacy adoption / v8 format preserved")
	b.scene.ready_to_save=false;b.free();done=true;quit()
