extends SceneTree
const Schema = preload("res://simulation/units/unit_schema.gd")
const Timers = preload("res://simulation/systems/tick_timers.gd")
const Locomotion = preload("res://simulation/systems/locomotion.gd")
const Clock = preload("res://simulation/systems/action_clock.gd")
var done := false

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false)
	_record_fields(game, battle)
	for tick in range(60): battle.world.battle_simulation._sim_step(battle.SIM_DT)
	for unit in battle.units:
		assert(Schema.omissions(unit).is_empty(), "Unregistered runtime unit fields: " + str(Schema.omissions(unit)))
	assert(Schema.omissions({"new_unregistered_field":1}) == ["new_unregistered_field"])
	var source: Dictionary = battle.units.filter(func(unit): return not unit.is_building)[0].duplicate(true)
	for key in Schema.persisted_scalars(): source[key] = sentinel(key)
	source.path=[Vector2.ZERO,Vector2.ONE,Vector2(2,2)] # Keep the sentinel cursor inside a real route.
	var saved: Dictionary = game.snapshot([source], {}, {}).units[0].simulation
	var restored := {"dir":0,"is_building":false}
	Schema.restore_scalars(saved, restored)
	Timers.restore(saved,restored)
	Locomotion.restore(saved, restored)
	Clock.restore(saved, restored)
	preload("res://simulation/systems/stratagem_rules.gd").restore(saved, restored)
	assert(Schema.valid_snapshot(saved) and Timers.valid_snapshot(saved))
	for key in Schema.persisted_scalars():
		assert(saved.has(key), "Snapshot omitted " + key)
		assert(restored.has(key) and game.save_canonical_text({"value":restored[key]}) == game.save_canonical_text({"value":source[key]}), "Restore omitted/changed " + key)
		var invalid := saved.duplicate(true); invalid[key] = {"invalid":true} if Schema.FIELDS[key].type != "Dictionary" else "invalid"
		assert(not Schema.valid_snapshot(invalid) or not Timers.valid_snapshot(invalid), "Validator omitted " + key)
	var snapshot: Dictionary = game.snapshot(battle.units, battle.world.economy.player_resources(), battle.saver.save_extra())
	battle.selecting=true; battle.drag_pan=true; battle.feedback_text="old world"; battle.cmd_pending="build"; battle.cmd_pending_data={"old":true}; battle.duel_pending=true
	var transaction = load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure=true
	assert(not battle.saver.apply_snapshot(snapshot) and battle.selecting and battle.drag_pan and battle.duel_pending)
	transaction.force_view_failure=false
	assert(battle.saver.apply_snapshot(snapshot))
	assert(not battle.selecting and not battle.drag_pan and battle.feedback_text.is_empty())
	assert(battle.cmd_pending.is_empty() and battle.cmd_pending_data.is_empty() and not battle.duel_pending)
	assert("selecting" not in battle.state.PROXY_FIELDS and "feedback_text" not in battle.state.PROXY_FIELDS)
	battle.scene.ready_to_save=false; battle.free()
	print("UNIT SCHEMA PASS registered runtime keys / every scalar serialized-validated-restored / transient reset")
	done=true; quit()

func sentinel(key: String):
	var field: Dictionary = Schema.FIELDS[key]
	match field.type:
		"bool": return true
		"int": return mini(1, int(field.get("max", 2147483647)))
		"float": return 1.25
		"String": return field.get("values", ["wood"])[-1]
		"Array": return [27]
		"Dictionary": return {"wood":1}
	return field.default

func _record_fields(game: Node, battle: Node2D) -> void:
	var original: Dictionary = game.snapshot(battle.units, battle.world.economy.player_resources(), battle.saver.save_extra())
	var seed: Array = battle.units.duplicate(true)
	var worker_index: int = seed.find(seed.filter(func(unit): return int(unit.unit) == 30)[0])
	var extra: Dictionary = battle.saver.save_extra(); extra.simulation.ai={}
	for field in Schema.fields("record"):
		battle.ai=null
		var units := seed.duplicate(true)
		var index := worker_index
		if field == "is_building": index=units.find(units.filter(func(unit): return unit.is_building)[0])
		var unit: Dictionary = units[index]
		unit.group_officer=-1
		match field:
			"uid": unit.uid += 10000
			"alive": unit.alive=false; unit.hp=0; unit.state="dead"
			"ax", "ay": unit[field] += 0.25
			"hp": unit.hp -= 1
			"owner": unit.owner=2 if int(unit.owner)!=2 else 3
			"unit": unit.unit=32
			"is_building": pass # Factory classification must agree with the saved unit type.
			"map_object": unit.map_object=false
			"map_index": unit.map_index=137
			"die_t": unit.die_t=0.5; unit.state="dead"; unit.hp=-7
			"state": unit.state="move"
			"officer": unit.officer=battle.world.officer_pool._officer_by_index(0).duplicate(true)
			_: unit[field]=sentinel(field)
		var saved: Dictionary = game.snapshot(units, battle.world.economy.player_resources(), extra)
		var key: String = Schema.FIELDS[field].key
		var record: Dictionary = saved.units[index]
		assert(record.has(key) and Schema.valid_record(record), "Record serialization/validation omitted " + field)
		var invalid := saved.duplicate(true)
		invalid.units[index][key]="invalid" if Schema.FIELDS[field].type=="Dictionary" and field!="officer" else {"invalid":true}
		assert(not Schema.valid_record(invalid.units[index]), "Record type validation omitted " + field)
		assert(not battle.saver.apply_snapshot(invalid))
		assert(battle.saver.apply_snapshot(saved), "Record restore rejected " + field)
		var restored: Dictionary = battle.units.filter(func(value): return int(value.uid)==int(record.uid))[0]
		var after: Dictionary = Schema.snapshot_record(restored)
		assert(game.save_canonical_text({"value":record[key]})==game.save_canonical_text({"value":after[key]}), "Record restore omitted " + field)
	assert(battle.saver.apply_snapshot(original))
	print("UNIT RECORD SCHEMA PASS every record field / actual candidate restoration / wire aliases / invalid types")
