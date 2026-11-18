extends RefCounted
## Whole-world exchange. Old data/nodes remain owned until staging succeeds.
const Fields = preload("res://simulation/battle_state_fields.gd")
static var force_view_failure := false
static var force_view_failure_after_attach := false

func apply(live: Node2D, snapshot: Dictionary, records: Array, plan: Dictionary) -> bool:
	var missing := Fields.omissions(live.state)
	if not missing.is_empty():
		push_warning("Snapshot field policy is incomplete: " + str(missing)); return false
	var candidate = preload("res://app/saves/candidate_world.gd").new()
	if not candidate.prepare(live.state, live.world.definition) or not candidate.saver.restore_candidate(snapshot, records, plan):
		candidate.dispose(); return false
	return install(live,candidate)

func install(live: Node2D, candidate: RefCounted, cross_map := false) -> bool:
	if live.view!=null and DisplayServer.get_name()!="headless":candidate.state.nav.warm_runtime_shapes()
	if force_view_failure:
		candidate.dispose(); return false
	var view = live.view
	var map_plan := {}
	var previous_map := str(live.state.map_id)
	var old_plan := {}
	var old_position := Vector2.ZERO
	var old_zoom := Vector2.ONE
	if view != null and cross_map:
		map_plan = view.prepare_map_terrain(str(candidate.state.map_id))
		if map_plan.is_empty():
			candidate.dispose()
			return false
		old_plan = view.prepare_map_terrain(previous_map)
		old_position = view.cam.position
		old_zoom = view.cam.zoom
	var lease: int = Game.pauses.acquire(live, "world exchange") if cross_map else 0
	var presentation: Dictionary = view.stage_world_nodes() if view != null else {}
	var previous: RefCounted = live.exchange_world(candidate.world)
	if view != null:
		var complete: bool = view.attach_loaded_world(live.units,live.sheet_by_unit)
		var terrain_attempted := cross_map and complete and not force_view_failure_after_attach
		if terrain_attempted: complete = view.switch_map_terrain(str(candidate.state.map_id), map_plan)
		if force_view_failure_after_attach or not complete:
			live.exchange_world(previous)
			view.rollback_world_nodes(presentation)
			if terrain_attempted: view.rollback_map_terrain(previous_map, old_plan, old_position, old_zoom)
			Game.pauses.release(lease)
			candidate.dispose(); return false
		view.commit_world_nodes(presentation)
		if cross_map: view.finish_map_change()
		view.finish_loaded_world(live.units,live.game_end)
	live.scene.reset_transients()
	live.cmd_pending = ""
	live.cmd_pending_data = {}
	live.visibility.set_full_reveal(live.cheat_reveal)
	live.commands.session._set_cheat_input(false)
	if cross_map:
		live.scene.sec_visible.clear()
		for unit in live.state.units: live.scene.sec_visible[int(unit.owner)] = true
		Game.pauses.release(lease)
	candidate.world = null
	candidate.saver = null
	previous.dispose()
	return true
