extends RefCounted
## Whole-world exchange. Old data/nodes remain owned until staging succeeds.
const Fields = preload("res://simulation/state/battle_state_fields.gd")
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
	if live.view!=null and DisplayServer.get_name()!="headless":candidate.world.nav.warm_runtime_shapes()
	if force_view_failure:
		candidate.dispose(); return false
	var view = live.view
	var ops: Object = preload("res://app/battle/runtime/view_ops.gd").new(view) if view != null else null
	var map_plan := {}
	var staged_terrain: Node2D
	var old_position := Vector2.ZERO
	var old_zoom := Vector2.ONE
	if view != null and cross_map:
		map_plan = ops.prepare_map_terrain(str(candidate.state.map_id))
		if map_plan.is_empty():
			candidate.dispose()
			return false
		old_position = ops.camera().position
		old_zoom = ops.camera().zoom
	var lease: int = Game.pauses.acquire(live, "world exchange") if cross_map else 0
	var presentation: Dictionary = ops.stage_world_nodes() if view != null else {}
	var stable_queries = ops.host() if ops != null else null
	var preview: Node2D
	var visual_rows: Array
	if view != null:
		var queries := preload("res://app/read_models/battle_queries.gd").new(candidate)
		preview = live.create_view_context_for(queries, view)
		ops.set_host(preview)
		visual_rows = preload("res://app/read_models/unit_projection.gd").staged_units(candidate.state.units, candidate.state.sheet_by_unit)
		var complete: bool = ops.attach_loaded_world(visual_rows) == true
		var terrain_attempted := cross_map and complete
		if terrain_attempted:
			staged_terrain = ops.stage_map_terrain(str(candidate.state.map_id), map_plan)
			complete = staged_terrain != null
		ops.set_host(stable_queries)
		preview.free()
		if force_view_failure_after_attach or not complete:
			if staged_terrain != null: staged_terrain.free()
			ops.rollback_world_nodes(presentation)
			if terrain_attempted:
				ops.camera().position = old_position
				ops.camera().zoom = old_zoom
			Game.pauses.release(lease)
			candidate.dispose(); return false
	var previous: RefCounted = live.exchange_world(candidate.world)
	candidate.world = null
	candidate.saver = null
	# Release the resources whose lifetime is no longer conditional before the purely
	# presentational tail: a script error later in this function must not leak the whole
	# previous world or keep the scene paused forever.
	if view != null:
		ops.commit_world_nodes(presentation)
		if cross_map:
			ops.commit_map_terrain(staged_terrain)
			ops.finish_map_change()
	previous.dispose()
	if cross_map: Game.pauses.release(lease)
	if view != null:
		ops.finish_loaded_world(visual_rows,live.game_end)
	live.scene.reset_transients()
	live.cmd_pending = ""
	live.cmd_pending_data = {}
	live.visibility.set_full_reveal(live.cheat_reveal)
	live.cheat_controller._set_cheat_input(false)
	if cross_map:
		live.scene.sec_visible.clear()
		for unit in live.state.units: live.scene.sec_visible[int(unit.owner)] = true
	return true
