extends SceneTree
const Schema = preload("res://simulation/definitions/unit_schema.gd")
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
	for tick in range(60): battle.commands.world._sim_step(battle.SIM_DT)
	for unit in battle.units:
		assert(Schema.omissions(unit).is_empty(), "Unregistered runtime unit fields: " + str(Schema.omissions(unit)))
	assert(Schema.omissions({"new_unregistered_field":1}) == ["new_unregistered_field"])
	var source: Dictionary = battle.units.filter(func(unit): return not unit.is_building)[0].duplicate(true)
	for key in Schema.persisted_scalars(): source[key] = sentinel(key)
	var saved: Dictionary = game.snapshot([source], {}, {}).units[0].simulation
	var restored := {"dir":0,"is_building":false}
	Schema.restore_scalars(saved, restored)
	Timers.restore(saved, 8, restored)
	Locomotion.restore(saved, restored)
	Clock.restore(saved, restored)
	preload("res://simulation/systems/stratagem_rules.gd").restore(saved, restored)
	assert(Schema.valid_snapshot(saved) and Timers.valid_snapshot(saved,8))
	for key in Schema.persisted_scalars():
		assert(saved.has(key), "Snapshot omitted " + key)
		assert(restored.has(key) and game.save_canonical_text({"value":restored[key]}) == game.save_canonical_text({"value":source[key]}), "Restore omitted/changed " + key)
		var invalid := saved.duplicate(true); invalid[key] = {"invalid":true} if Schema.FIELDS[key].type != "Dictionary" else "invalid"
		assert(not Schema.valid_snapshot(invalid) or not Timers.valid_snapshot(invalid,8), "Validator omitted " + key)
	var snapshot: Dictionary = game.snapshot(battle.units, battle.commands.world._resources(), battle.saver.save_extra())
	battle.selecting=true; battle.drag_pan=true; battle.feedback_text="old world"; battle.cmd_pending="build"; battle.cmd_pending_data={"old":true}; battle._input_command=true
	var transaction = load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure=true
	assert(not battle.saver.apply_snapshot(snapshot) and battle.selecting and battle.drag_pan and battle._input_command)
	transaction.force_view_failure=false
	assert(battle.saver.apply_snapshot(snapshot))
	assert(not battle.selecting and not battle.drag_pan and battle.feedback_text.is_empty())
	assert(battle.cmd_pending.is_empty() and battle.cmd_pending_data.is_empty() and not battle._input_command)
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
