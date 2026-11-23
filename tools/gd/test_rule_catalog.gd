extends SceneTree
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
const Contract = preload("res://simulation/definitions/contracts/rule_contract.gd")
const Loader = preload("res://app/rules/rule_loader.gd")
const Stratagem = preload("res://simulation/combat/stratagem_rules.gd")
const Identity = preload("res://app/saves/rules_identity.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	assert(game.startup_valid and Catalog.is_ready() and Loader.read_count == Contract.FILES.size())
	assert(Loader.initialize().is_empty() and Loader.read_count == Contract.FILES.size())
	if "--rules-expect-script" in OS.get_cmdline_user_args():
		assert(preload("res://simulation/native/math_kernel.gd").get_kernel() == null)
	# Remove source files before the FIRST rules-system query, including config().
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rules-delete-fixture="):
			var fixture := argument.trim_prefix("--rules-delete-fixture=")
			assert(ProjectSettings.globalize_path("res://").simplify_path() == fixture.simplify_path())
			for name in Contract.FILES: assert(DirAccess.remove_absolute("res://data/db/" + name) == OK)
	var tuning := Stratagem.config()
	for name in Contract.FILES: assert(_frozen(Catalog.get_catalog(name)))
	for frame in range(1000): assert(is_same(tuning, Stratagem.config()))
	_contracts()
	_loader_failures()
	var reads := Loader.read_count
	var fingerprint := Identity.current() # Must fingerprint installed rules, not re-open JSON.
	game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle); battle.set_process(false)
	assert(is_same(battle.command_rules.model, Catalog.get_catalog("command_variants.json").three_layer_model))
	assert(is_same(battle.rules.missions, Catalog.get_catalog("scenario_rules.json").missions))
	var actor: Dictionary = battle.selected[0]
	Stratagem.set_status(actor, 2); Stratagem.set_status(actor, 4)
	assert(actor.haste_t == tuning.statusTicks and actor.farsight_t == tuning.statusTicks)
	for tick in range(4): battle.world.battle_simulation._sim_step(battle.SIM_DT)
	assert(actor.haste_t == tuning.statusTicks - 4 and actor.farsight_t == tuning.statusTicks - 4)
	var simulation: Object = battle.world.battle_simulation
	assert(simulation.tick_microseconds == 0 and battle.nav.performance_counters().microseconds == 0)
	simulation.profile_enabled = true; battle.nav.set_profiling(true)
	battle.world.battle_simulation._sim_step(battle.SIM_DT)
	battle.nav.find_path(Vector2(actor.ax, actor.ay), Vector2(actor.ax, actor.ay), true)
	assert(simulation.tick_microseconds > 0 and battle.nav.performance_counters().microseconds > 0)
	simulation.profile_enabled = false; battle.nav.set_profiling(false); simulation = null
	_worlds(game, battle)
	assert(is_same(tuning, Stratagem.config()) and Identity.current() == fingerprint and Loader.read_count == reads)
	var world: WeakRef = weakref(battle.world)
	battle.scene.ready_to_save = false; battle.free(); actor = {}
	assert(world.get_ref() == null and _frozen(tuning))
	print("RULE CATALOG PASS startup once / all catalogs frozen / atomic validation / no tick or candidate I/O / opt-in profiling / isolated officers / rollback and exchange / old worlds released")
	quit()

func _contracts() -> void:
	var documents := {}
	for name in Contract.FILES: documents[name] = Catalog.get_catalog(name).duplicate(true)
	assert(Contract.errors(documents).is_empty())
	for name in Contract.FILES:
		var value: Dictionary = documents[name]; var backup := value.duplicate(true)
		value.clear()
		assert(not Contract.valid(name, value), "Required gameplay fields: " + name)
		documents[name] = backup
	assert(not Contract.valid("unit_tuning.json", {"statusTicks":800,"hasteMoveMultiplier":0,"slowMoveMultiplier":0.5,"farsightCells":10}))
	var bad: Dictionary = documents["unit_tuning.json"].duplicate(true)
	var status = preload("res://simulation/definitions/status_fields.gd")
	var schema = preload("res://simulation/units/unit_schema.gd")
	bad.statusTicks = status.MAX_TICKS
	assert(Contract.valid("unit_tuning.json", bad))
	for field in status.KEYS: assert(schema.FIELDS[field].max == status.MAX_TICKS)
	bad.statusTicks += 1
	assert(not Contract.valid("unit_tuning.json", bad), "Status duration must match save/timer bounds")
	bad = documents["scenario_rules.json"].duplicate(true)
	bad.missions.values()[0].stages[0].condition = {"kind":"unhandled"}
	assert(not Contract.valid("scenario_rules.json", bad))
	bad = documents["unit_definitions.json"].duplicate(true)
	bad.units.values()[0].clips = {"walk":[[]]}
	assert(not Contract.valid("unit_definitions.json", bad))
	var installed := Catalog.get_catalog("unit_tuning.json")
	assert(not Catalog.install(documents).is_empty() and is_same(installed, Catalog.get_catalog("unit_tuning.json")))
	var opening = preload("res://app/battle/startup/opening_officers.gd")
	var first: Array = opening.pool([]); var second: Array = opening.pool([])
	first[0][0].level = 9
	assert(second[0][0].level == 5 and Catalog.get_catalog("officers.json").blocks[0].officers[0].level == 0)
	var rules = preload("res://simulation/definitions/unit_rules.gd")
	var buildings = preload("res://simulation/definitions/building_rules.gd")
	var map_a := {"units":{}}; var map_b := {"units":{}}
	assert(rules.apply_definitions(map_a) and rules.apply_definitions(map_b))
	buildings.apply_definitions(map_a); buildings.apply_definitions(map_b)
	var original: float = map_b.units["30"].costs[0]
	map_a.units["30"].costs[0] += 1; map_a.units["0"].constructionFrames[0] += 1
	assert(map_b.units["30"].costs[0] == original and Catalog.get_catalog("production_units.json").units["30"].costs[0] == original)
	assert(map_b.units["0"].constructionFrames[0] == Catalog.get_catalog("buildings.json").units["0"].constructionFrames[0])

func _loader_failures() -> void:
	var directory := "user://rule-loader-test"
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	for name in Contract.FILES:
		var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		file.store_string(JSON.stringify(Catalog.get_catalog(name))); file.close()
	var good := Loader.read_bundle(directory)
	assert(good.errors.is_empty() and good.documents.size() == Contract.FILES.size())
	var roles: Dictionary = Catalog.get_catalog("unit_roles.json").duplicate(true)
	roles.workers.append(999)
	var reference := FileAccess.open(directory.path_join("unit_roles.json"), FileAccess.WRITE)
	reference.store_string(JSON.stringify(roles)); reference.close()
	var rejected := Loader.read_bundle(directory)
	assert(rejected.documents.is_empty() and str(rejected.errors).contains("reference"))
	reference = FileAccess.open(directory.path_join("unit_roles.json"), FileAccess.WRITE)
	reference.store_string(JSON.stringify(Catalog.get_catalog("unit_roles.json"))); reference.close()
	var file := FileAccess.open(directory.path_join("command_variants.json"), FileAccess.WRITE)
	file.store_string("{broken"); file.close()
	file = FileAccess.open(directory.path_join("officers.json"), FileAccess.WRITE)
	file.store_string("{}"); file.close()
	assert(DirAccess.remove_absolute(directory.path_join("unit_tuning.json")) == OK)
	var failed := Loader.read_bundle(directory)
	assert(failed.documents.is_empty() and failed.errors.size() == 3)
	assert(str(failed.errors).contains("unit_tuning.json") and str(failed.errors).contains("command_variants.json") and str(failed.errors).contains("officers.json"))
	assert(Catalog.is_ready() and Stratagem.config().statusTicks == 800)
	for name in Contract.FILES: DirAccess.remove_absolute(directory.path_join(name))
	assert(DirAccess.remove_absolute(directory) == OK)

func _worlds(game: Node, battle: Node2D) -> void:
	var snapshot: Dictionary = game.snapshot(battle.units, battle.world.economy.player_resources(), battle.saver.save_extra())
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	var old: WeakRef = weakref(battle.world)
	var transaction = load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure_after_attach = battle.view != null
	transaction.force_view_failure = battle.view == null
	assert(not battle.saver.apply_snapshot(snapshot))
	transaction.force_view_failure_after_attach = false; transaction.force_view_failure = false
	assert(is_same(battle.world, old.get_ref()) and game.save_checksum(battle.saver.continuation_snapshot(game)) == before)
	assert(battle.saver.apply_snapshot(snapshot) and old.get_ref() == null)
	assert(is_same(battle.command_rules.model, Catalog.get_catalog("command_variants.json").three_layer_model))
	assert(is_same(battle.rules.missions, Catalog.get_catalog("scenario_rules.json").missions))
	battle.world.battle_simulation._sim_step(battle.SIM_DT)

func _frozen(value) -> bool:
	if value is Array or value is Dictionary:
		if not value.is_read_only(): return false
		for child in value.values() if value is Dictionary else value:
			if not _frozen(child): return false
	return not value is Object
