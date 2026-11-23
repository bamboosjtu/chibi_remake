extends RefCounted
## A replacement keeps the previous world and view recoverable until commit.
const Fields = preload("res://simulation/state/battle_state_fields.gd")
const ViewOps = preload("res://app/battle/runtime/view_ops.gd")

enum CommitFailure { NONE, AFTER_EXCHANGE, AFTER_NODES, AFTER_TERRAIN }
static var commit_failure := CommitFailure.NONE
static var force_view_failure := false
static var force_view_failure_after_attach := false

func apply(live: Node2D, snapshot: Dictionary, records: Array, plan: Dictionary) -> bool:
	var missing := Fields.omissions(live.state)
	if not missing.is_empty():
		push_warning("Snapshot field policy is incomplete: " + str(missing)); return false
	var candidate = preload("res://app/saves/candidate_world.gd").new()
	if not candidate.prepare(live.world, live.world.definition) or not candidate.saver.restore_candidate(snapshot, records, plan):
		candidate.dispose(); return false
	return install(live,candidate)

func install(live: Node2D, candidate: RefCounted, cross_map := false) -> bool:
	if force_view_failure:
		candidate.dispose()
		return false
	var view: Node2D = live.view
	var ops := ViewOps.new(view) if view != null else null
	var lease := int(Game.pauses.acquire(live, "world exchange")) if cross_map else 0
	var presentation := {}
	var rows: Array = []
	if ops != null:
		if DisplayServer.get_name() != "headless": candidate.world.nav.warm_runtime_shapes()
		var queries := preload("res://app/read_models/battle_queries.gd").new(candidate)
		var preview: Node2D = live.create_view_context_for(queries, view)
		rows = preload("res://app/read_models/unit_projection.gd").staged_units(candidate.state.units, candidate.state.sheet_by_unit)
		presentation = ops.stage(preview, rows, str(candidate.state.map_id), cross_map)
		preview.free()
	var ready := ops == null or (not presentation.is_empty() and not force_view_failure_after_attach)
	var previous: RefCounted
	var committed := false
	if ready:
		previous = live.exchange_world(candidate.world)
		committed = _apply_view(ops, presentation, cross_map)
	if not committed and previous != null: live.exchange_world(previous)
	Game.pauses.release(lease)
	if not committed:
		if ops != null: ops.rollback(presentation)
		candidate.dispose()
		return false

	candidate.world = null
	candidate.saver = null
	previous.dispose()
	if ops != null: ops.release_previous(presentation)
	_reset_scene(live, cross_map)
	if ops != null: ops.finish(presentation, rows, live.game_end)
	return true

func _apply_view(ops: ViewOps, presentation: Dictionary, cross_map: bool) -> bool:
	if _fail_at(CommitFailure.AFTER_EXCHANGE): return false
	if ops == null: return true
	if not ops.apply_nodes(presentation) or _fail_at(CommitFailure.AFTER_NODES): return false
	if not cross_map: return true
	return ops.apply_terrain(presentation) and not _fail_at(CommitFailure.AFTER_TERRAIN)

func _fail_at(phase: CommitFailure) -> bool:
	if commit_failure != phase: return false
	commit_failure = CommitFailure.NONE
	return true

func _reset_scene(live: Node2D, cross_map: bool) -> void:
	live.scene.reset_transients()
	live.cmd_pending = ""
	live.cmd_pending_data = {}
	live.visibility.set_full_reveal(live.cheat_reveal)
	live.cheat_controller._set_cheat_input(false)
	if cross_map:
		live.scene.sec_visible.clear()
		for unit in live.state.units: live.scene.sec_visible[int(unit.owner)] = true
