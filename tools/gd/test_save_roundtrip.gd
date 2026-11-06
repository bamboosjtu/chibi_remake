extends SceneTree
## Seeded sample points exercise actual save -> restore -> continuation with AI.
const Fields = preload("res://simulation/battle_state_fields.gd")
const Digest = preload("res://simulation/systems/state_digest.gd")
var done := false

class UnregisteredState extends RefCounted:
	var unexpected_field := 1

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game := root.get_node("Game")
	game.current_map = "chibic1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var identity: int = battle.get_instance_id()
	assert(Fields.omissions(battle.state).is_empty())
	assert(Fields.omissions(UnregisteredState.new()).has("unexpected_field"))
	var samples := RandomNumberGenerator.new()
	samples.seed = 20261106
	for sample in range(6):
		for tick in range(samples.randi_range(7, 57)): battle.commands._sim_step(battle.SIM_DT)
		var before: Dictionary = Digest.sections(battle, game)
		var combat: String = game.save_canonical_text(Digest.snapshot(battle).combat)
		assert(battle.commands._save_game())
		var snapshot: Dictionary = game.load_save()
		for tick in range(19): battle.commands._sim_step(battle.SIM_DT)
		var continued: Dictionary = Digest.sections(battle, game)
		assert(battle.saver.apply_snapshot(snapshot))
		assert(battle.get_instance_id() == identity)
		if Digest.sections(battle, game) != before:
			print("ROUNDTRIP expected: ", before, " actual: ", Digest.sections(battle, game))
			FileAccess.open("user://roundtrip-before.json", FileAccess.WRITE).store_string(JSON.stringify(snapshot))
			assert(battle.commands._save_game())
			FileAccess.open("user://roundtrip-after.json", FileAccess.WRITE).store_string(JSON.stringify(game.load_save()))
			FileAccess.open("user://combat-before.json", FileAccess.WRITE).store_string(combat)
			FileAccess.open("user://combat-after.json", FileAccess.WRITE).store_string(game.save_canonical_text(Digest.snapshot(battle).combat))
		assert(Digest.sections(battle, game) == before, "Round-trip digest sample %d" % sample)
		for tick in range(19): battle.commands._sim_step(battle.SIM_DT)
		assert(Digest.sections(battle, game) == continued, "Continuation digest sample %d" % sample)
	var invalid: Dictionary = game.load_save().duplicate(true)
	invalid.units[0].simulation.build_targetUid = 2147483646
	var current: Dictionary = Digest.sections(battle, game)
	assert(not battle.saver.apply_snapshot(invalid))
	assert(Digest.sections(battle, game) == current)
	var retained: WeakRef = weakref(battle.state)
	battle.free()
	assert(retained.get_ref() == null, "Save candidates must not retain closed worlds")
	print("SAVE ROUNDTRIP PASS six seeded AI samples / continuation / field policy / atomic rejection / lifecycle")
	done = true
	quit()
