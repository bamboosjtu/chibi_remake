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
	var snapshot: Dictionary = game.snapshot(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra())
	var before: Dictionary = Digest.sections(battle,game)
	var entry_id: int = battle.get_instance_id()
	var commands_id: int = battle.commands.get_instance_id()
	var state_id: int = battle.state.get_instance_id()
	var sprite_id: int = battle.view.unit_nodes(battle.units[0]).spr.get_instance_id()
	Transaction.force_view_failure_after_attach = true
	assert(not battle.saver.apply_snapshot(snapshot))
	Transaction.force_view_failure_after_attach = false
	assert(battle.state.get_instance_id() == state_id)
	assert(Digest.sections(battle,game) == before)
	assert(battle.view.unit_nodes(battle.units[0]).spr.get_instance_id() == sprite_id)
	var old_world: WeakRef = weakref(battle.world)
	var old_epoch: int = battle.world.get_instance_id()
	assert(battle.saver.apply_snapshot(snapshot))
	assert(battle.get_instance_id() == entry_id and battle.commands.get_instance_id() == commands_id)
	assert(battle.state.get_instance_id() != state_id and old_world.get_ref() == null)
	assert(Digest.sections(battle,game) == before)
	var ticket: int = battle.state.effects.reserve_duel({"test":1})
	battle._modules.duel_controller._complete_duel(ticket,old_epoch)
	assert(battle.state.effects.take_duel(ticket).test == 1)
	var retained: WeakRef = weakref(battle.state)
	battle.free()
	assert(retained.get_ref() == null)
	print("WORLD EXCHANGE PASS staged view rollback / stable entry and commands / old world released / immutable definition / stale duel ticket")
	done = true
	quit()
