extends SceneTree
const Digest = preload("res://simulation/diagnostics/state_digest.gd")
var Transaction: Script
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func run() -> void:
	var game := root.get_node("Game")
	Transaction = load("res://app/saves/world_transaction.gd")
	var without_startup = load("res://main.tscn").instantiate()
	var unused_factory: WeakRef = weakref(without_startup.presentation)
	without_startup.free()
	assert(unused_factory.get_ref() == null)
	game.current_map = "chibic1"
	var other = load("res://main.tscn").instantiate()
	root.add_child(other)
	other.set_process(false)
	var cross_snapshot: Dictionary = game.snapshot(other.units, other.world.economy.player_resources(), other.scene_controller._save_extra())
	other.free()
	game.current_map = "chibil1"
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	if battle.view != null: battle.view.event_view.restore_history()
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
	var queries_id: int = battle.view.host.queries.get_instance_id() if battle.view != null else 0
	var state_id: int = battle.state.get_instance_id()
	var sprite_id: int = _sprite_id(battle)
	Transaction.force_view_failure = battle.view == null
	Transaction.force_view_failure_after_attach = battle.view != null
	assert(not battle.saver.apply_snapshot(snapshot))
	Transaction.force_view_failure = false
	Transaction.force_view_failure_after_attach = false
	assert(battle.state.get_instance_id() == state_id)
	assert(Digest.sections(battle,game) == before)
	assert(_sprite_id(battle) == sprite_id)
	assert(_verify_failures(battle, game, snapshot, false))
	var old_service: WeakRef = weakref(battle.world.combat)
	var old_state: WeakRef = weakref(battle.state)
	var old_world: WeakRef = weakref(battle.world)
	var old_epoch: int = battle.world.get_instance_id()
	assert(battle.saver.apply_snapshot(snapshot))
	assert(battle.get_instance_id() == entry_id and battle.actions.get_instance_id() == actions_id)
	assert(battle.session_actions.get_instance_id() == session_id)
	if battle.view != null: assert(battle.view.host.queries.get_instance_id() == queries_id)
	assert(battle.state.get_instance_id() != state_id and old_world.get_ref() == null)
	assert(old_service.get_ref() == null and old_state.get_ref() == null)
	assert(Digest.sections(battle,game) == before)
	assert(battle.world.get_instance_id() != old_epoch)
	assert(await _verify_cross_map(battle, game, cross_snapshot))
	if battle.view != null: assert(_verify_cold_camera(battle, snapshot))
	var retained: WeakRef = weakref(battle.state)
	var factory: WeakRef = weakref(battle.presentation)
	battle.free()
	assert(retained.get_ref() == null)
	assert(factory.get_ref() == null)
	print("WORLD EXCHANGE PASS staged view rollback / stable actions / old world and services released / immutable definition")
	done = true
	quit()

func _sprite_id(battle: Node2D) -> int:
	return battle.view.unit_nodes(battle.units[0]).spr.get_instance_id() if battle.view != null else 0

func _verify_failures(battle: Node2D, game: Node, snapshot: Dictionary, cross_map: bool) -> bool:
	var before := Digest.sections(battle, game)
	var world_id: int = battle.world.get_instance_id()
	var sprite_id := _sprite_id(battle)
	var view = battle.view
	var terrain: Node2D = view.world_layers.terrain if view != null else null
	var minimap: Texture2D = view.minimap.map_texture if view != null and view.minimap != null else null
	var position: Vector2 = view.cam.position if view != null else Vector2.ZERO
	var zoom: Vector2 = view.cam.zoom if view != null else Vector2.ONE
	var phases := [Transaction.CommitFailure.AFTER_EXCHANGE]
	if view != null:
		phases.append(Transaction.CommitFailure.AFTER_NODES)
		if cross_map: phases.append(Transaction.CommitFailure.AFTER_TERRAIN)
	var pause_count: int = game.pauses.count()
	for phase in phases:
		Transaction.commit_failure = phase
		var installed: bool = _restore(battle, snapshot, cross_map)
		assert(not installed and Transaction.commit_failure == Transaction.CommitFailure.NONE, "Fault must execute at stage " + str(phase))
		assert(battle.world.get_instance_id() == world_id and Digest.sections(battle, game) == before)
		assert(_sprite_id(battle) == sprite_id and game.pauses.count() == pause_count)
		if view != null:
			assert(view.world_layers.terrain == terrain and not terrain.is_queued_for_deletion())
			assert(view.cam.position == position and view.cam.zoom == zoom)
			if view.minimap != null: assert(view.minimap.map_texture == minimap)
		var actors: Array = battle.units.filter(func(unit):
			return unit.alive and not unit.is_building and int(unit.owner) == battle.player_owner)
		assert(battle.world.player_commands.submit("stop", actors.slice(0, 1)) == 1)
		battle.world.player_commands.clear()
	return true

func _restore(battle: Node2D, snapshot: Dictionary, cross_map: bool) -> bool:
	if cross_map: return battle.saver.apply_loaded({"data": snapshot, "source": "primary"}, true)
	return battle.saver.apply_snapshot(snapshot)

func _verify_cross_map(battle: Node2D, game: Node, snapshot: Dictionary) -> bool:
	var lease: int = game.pauses.acquire(battle, "another modal")
	assert(_verify_failures(battle, game, snapshot, true))
	var previous: WeakRef = weakref(battle.world)
	var terrain: WeakRef = weakref(battle.view.world_layers.terrain) if battle.view != null else null
	assert(_restore(battle, snapshot, true))
	assert(battle.map_id == snapshot.map and previous.get_ref() == null)
	assert(game.pauses.is_top(lease))
	game.pauses.release(lease)
	assert(not paused)
	await process_frame
	if terrain != null: assert(terrain.get_ref() == null)
	print("WORLD COMMIT PASS reversible world / nodes / terrain, modal leases and retry")
	return true

func _verify_cold_camera(battle: Node2D, snapshot: Dictionary) -> bool:
	battle.view.cam.free()
	battle.view.cam = null
	battle.cam = null
	Transaction.commit_failure = Transaction.CommitFailure.AFTER_TERRAIN
	assert(not _restore(battle, snapshot, true))
	assert(Transaction.commit_failure == Transaction.CommitFailure.NONE and battle.view.cam == null)
	assert(_restore(battle, snapshot, true))
	assert(battle.view.cam != null and battle.view.cam.is_current())
	return true
