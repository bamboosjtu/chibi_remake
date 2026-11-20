extends SceneTree
const Semantics = preload("res://app/saves/snapshot_semantics.gd")
const Limits = preload("res://app/saves/json_limits.gd")
const Store = preload("res://app/saves/json_store.gd")
var battle: Node2D
var game: Node
var done := false

func _initialize() -> void:
	create_timer(150).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	game=root.get_node("Game");game.current_map="chibic1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle);battle.set_process(false)
	var base: Dictionary=game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	var digest: String=game.save_checksum(battle.saver.continuation_snapshot(game))
	var identity: int=battle.state.get_instance_id()
	var invalids:=[]
	for axis in ["x","y"]:
		var invalid: Dictionary=base.duplicate(true);invalid.units[0][axis]=-10000.0;invalids.append(invalid)
		invalid=base.duplicate(true);invalid.units[0][axis]=1000000.0;invalids.append(invalid)
	for value in [-1,0.5,"1",2147483648.0]:
		var invalid: Dictionary=base.duplicate(true);invalid.units[0].simulation.pi=value;invalids.append(invalid)
	for field in ["fo_x","dir","site_entry_x"]:
		var invalid: Dictionary=base.duplicate(true);invalid.units[0].simulation[field]=1e100;invalids.append(invalid)
	var invalid: Dictionary=base.duplicate(true);invalid.units[0].simulation.path=[[1000000,0]];invalids.append(invalid)
	invalid=base.duplicate(true);invalid.units[0].simulation.repathTo=[0,-10000];invalids.append(invalid)
	invalid=base.duplicate(true);invalid.units[0].simulation.path.resize(int(battle.map_data.rows)*int(battle.map_data.cols)+3);invalid.units[0].simulation.path.fill([1,1]);invalids.append(invalid)
	for field in ["tick","rngState"]:
		invalid=base.duplicate(true);invalid.simulation[field]="9223372036854775808" if field=="rngState" else -1;invalids.append(invalid)
	for field in ["targetUid","join_target_uid"]:
		invalid=base.duplicate(true);invalid.units[0].simulation[field]=1.5;invalids.append(invalid)
	invalid=base.duplicate(true);invalid.units[0].simulation.build_cost={"future":{"bad":1}};invalids.append(invalid)
	var building_uid: int=base.units.filter(func(unit):return int(unit.owner)==battle.player_owner and int(unit.unit) in [0,1])[0].uid
	for cost in [{"unknown":1},{"gold":{"bad":1}},null]:
		invalid=base.duplicate(true)
		invalid.trainings=[{"buildingUid":building_uid,"unit":30,"cost":cost}]
		_signed(invalid);assert(not game.is_valid_save(invalid) and not game.can_rotate_save(invalid))
		invalids.append(invalid)
	for snapshot in invalids:
		_signed(snapshot)
		assert(not battle.saver.apply_snapshot(snapshot))
		assert(battle.state.get_instance_id()==identity and game.save_checksum(battle.saver.continuation_snapshot(game))==digest)
	_task_limits(base,identity,digest)
	_strict_navigation(base)
	_restore_ownership(base)
	_json_limits()
	_backup_source()
	battle.scene.ready_to_save=false;battle.free();done=true
	print("SAVE BOUNDARIES PASS checksum-correct rejection / map and route limits / strict cursor and derived caches / bounded tasks and JSON / backup provenance and same-size cache invalidation")
	quit()

func _signed(data: Dictionary) -> void:
	data.erase("checksum");data.checksum=game.save_checksum(data)
	assert(game.verify_save_checksum(data))

func _task_limits(base: Dictionary, identity: int, digest: String) -> void:
	var cases:=[]
	var invalid: Dictionary=base.duplicate(true);invalid.simulation.taskEvents=[]
	for index in range(Semantics.MAX_TASK_ENTRIES+1): invalid.simulation.taskEvents.append({"id":1,"tick":0})
	cases.append(invalid)
	invalid=base.duplicate(true);invalid.simulation.taskLatches={}
	for index in range(Semantics.MAX_TASK_ENTRIES+1): invalid.simulation.taskLatches[str(index)]=true
	cases.append(invalid)
	var deep: Array=[]
	for level in range(Semantics.MAX_TASK_DEPTH+1): deep=[deep]
	invalid=base.duplicate(true);invalid.simulation.taskLatches={"legacy":deep};cases.append(invalid)
	invalid=base.duplicate(true);invalid.simulation.taskEvents=["bad event"];cases.append(invalid)
	for snapshot in cases:
		_signed(snapshot)
		assert(not game.is_valid_save(snapshot),"File admission must also protect backup rotation")
		assert(not battle.saver.apply_snapshot(snapshot))
		assert(battle.state.get_instance_id()==identity and game.save_checksum(battle.saver.continuation_snapshot(game))==digest)
	assert(Semantics.valid_tasks({"taskLatches":{"future":{"flags":[true,null,1,"x"]}},"taskEvents":[{"id":999,"extra":{"text":"old extension"}}]}))
	assert(Semantics.valid_rng("-9223372036854775808") and Semantics.valid_rng("9223372036854775807"))
	assert(not Semantics.valid_rng("-9223372036854775809"))

func _strict_navigation(base: Dictionary) -> void:
	var index: int=base.units.find_custom(func(record):return int(record.unit)==30)
	var id: int=battle.state.get_instance_id()
	for change in [{"pi":999,"path":[[10,10]]},{"pi":17,"path":[]},{"A":1},{"pi":null}]:
		var snapshot: Dictionary=base.duplicate(true);snapshot.units[index].simulation.merge(change,true)
		_signed(snapshot);assert(not battle.saver.apply_snapshot(snapshot) and battle.state.get_instance_id()==id)
	var snapshot: Dictionary=base.duplicate(true)
	snapshot.units[index].simulation.targetUid=2147483647
	snapshot.units[index].simulation.join_target_uid=2147483647
	assert(battle.saver.apply_snapshot(snapshot))
	assert(battle.units[index].target==null and battle.units[index].join_target_uid==-1)
	assert(not snapshot.units[index].simulation.has("A"))

func _restore_ownership(base: Dictionary) -> void:
	var snapshot: Dictionary=base.duplicate(true)
	var building: Dictionary=snapshot.units.filter(func(unit):return int(unit.owner)==battle.player_owner and int(unit.unit) in [0,1])[0]
	snapshot.trainings=[{"buildingUid":building.uid,"owner":battle.player_owner,"unit":30,"t":25,"ticks":true,"cost":{"gold":400}}]
	snapshot.simulation.aiResources={"2":{"gold":200,"food":100,"wood":100,"stone":100}}
	assert(battle.saver.apply_snapshot(snapshot))
	snapshot.trainings[0].cost.gold=9999
	snapshot.simulation.aiResources["2"].gold=9999
	assert(battle.trainings[0].cost.gold==400 and battle.ai_res[2].gold==200)
	assert(battle.saver._valid_cost({"wood":1}) and not battle.saver._valid_cost({"future":1}))

func _json_limits() -> void:
	assert(Limits.valid_text('{"text":"quoted {[ brackets ]} and \\\" escape"}'))
	assert(Limits.valid_text(JSON.stringify({"text":"\\\""+"{[".repeat(1000)})))
	var folder: String=game.SAVE_PATH.get_base_dir()
	var path:=folder.path_join("limits.json")
	var stream:=FileAccess.open(path,FileAccess.WRITE)
	var deep: String='{"probe":'+"[".repeat(Limits.MAX_DEPTH)+"0"+"]".repeat(Limits.MAX_DEPTH)+'}'
	stream.store_string(deep);stream.close()
	assert(Store._read(path).is_empty())
	assert(Store.commit(path,'{"probe":1}'))
	assert(not Store.commit(path,deep) and Store._read(path).probe==1)
	stream=FileAccess.open(path,FileAccess.WRITE);stream.seek(Limits.MAX_BYTES);stream.store_8(32);stream.close()
	assert(Store._read(path).is_empty())
	DirAccess.remove_absolute(path)

func _backup_source() -> void:
	assert(game.save_game(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra(),19))
	assert(game.save_game(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra(),19))
	var path: String=game.save_slot_path(19)
	var text:=FileAccess.get_file_as_string(path)
	var data: Dictionary=JSON.parse_string(text)
	var damaged:=text.replace(str(data.checksum),"x".repeat(64))
	assert(damaged.length()==text.length())
	var matched:=false
	for attempt in range(3):
		var stream:=FileAccess.open(path,FileAccess.WRITE);stream.store_string(text);stream.close()
		assert(game._slot_info(19).source=="primary")
		var modified:=FileAccess.get_modified_time(path)
		stream=FileAccess.open(path,FileAccess.WRITE);stream.store_string(damaged);stream.close()
		if FileAccess.get_modified_time(path)==modified:
			matched=true;break
	assert(matched,"Fixture must preserve timestamp and length")
	assert(game._slot_info(19).source=="backup")
	var menu=load("res://presentation/shared/dialogs/save_slots_dialog.gd").new();root.add_child(menu);menu.open(false)
	var row: int=menu.entries.find_custom(func(entry):return int(entry.slot)==19)
	assert(menu.records.get_item_text(row).contains("使用备份"));menu._selected(row)
	assert(menu.status.text.contains("备份"));menu.free()
	game.pending_load_slot=19
	assert(battle.saver.apply() and battle.saver.last_load_source=="backup" and battle.feedback_text.contains("备份"))
	game.pending_load_slot=0
