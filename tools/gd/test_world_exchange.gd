extends SceneTree
const Digest = preload("res://simulation/systems/state_digest.gd")
var Transaction: Script
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	var game := root.get_node("Game")
	Transaction = load("res://app/saves/world_transaction.gd")
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.view.event_view.restore_history()
	assert(battle.world.definition.is_read_only())
	assert(battle.world.definition.units.is_read_only())
	var candidate = load("res://app/saves/candidate_world.gd").new()
	assert(candidate.prepare(battle.world, battle.world.definition))
	for key in ["economy","projectiles","fire_fields","transports","harvesting","construction","stratagems","command_rules","player_commands","rules","ai"]:
		assert(candidate.world.get(key).get_script() == battle.world.get(key).get_script(), "Different startup/candidate service: " + key)
	assert(candidate.world.combat != battle.world.combat)
	candidate.dispose()
	candidate.dispose()

	var snapshot: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.scene_controller._save_extra())
	var before: Dictionary = Digest.sections(battle,game)
	var entry_id: int = battle.get_instance_id()
	var actions_id: int = battle.actions.get_instance_id()
	var session_id: int = battle.session_actions.get_instance_id()
	var queries_id: int = battle.view.host.queries.get_instance_id()
	var state_id: int = battle.state.get_instance_id()
	var sprite_id: int = battle.view.unit_nodes(battle.units[0]).spr.get_instance_id()
	Transaction.force_view_failure_after_attach = true
	assert(not battle.saver.apply_snapshot(snapshot))
	Transaction.force_view_failure_after_attach = false
	assert(battle.state.get_instance_id() == state_id)
	assert(Digest.sections(battle,game) == before)
	assert(battle.view.unit_nodes(battle.units[0]).spr.get_instance_id() == sprite_id)
	var old_service: WeakRef = weakref(battle.world.combat)
	var old_state: WeakRef = weakref(battle.state)
	var old_world: WeakRef = weakref(battle.world)
	var old_epoch: int = battle.world.get_instance_id()
	assert(battle.saver.apply_snapshot(snapshot))
	assert(battle.get_instance_id() == entry_id and battle.actions.get_instance_id() == actions_id)
	assert(battle.session_actions.get_instance_id() == session_id and battle.view.host.queries.get_instance_id() == queries_id)
	assert(battle.state.get_instance_id() != state_id and old_world.get_ref() == null)
	assert(old_service.get_ref() == null and old_state.get_ref() == null)
	assert(Digest.sections(battle,game) == before)
	assert(battle.world.get_instance_id() != old_epoch)
	var retained: WeakRef = weakref(battle.state)
	battle.free()
	assert(retained.get_ref() == null)
	print("WORLD EXCHANGE PASS staged view rollback / stable actions / old world and services released / immutable definition")
	done = true
	quit()
