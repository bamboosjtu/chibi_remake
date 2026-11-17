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
	return _install(live,candidate)

func _install(live: Node2D, candidate: RefCounted) -> bool:
	if live.view!=null and DisplayServer.get_name()!="headless":candidate.state.nav.warm_runtime_shapes()
	if force_view_failure:
		candidate.dispose(); return false
	var view = live.view
	var presentation: Dictionary = view.stage_world_nodes() if view != null else {}
	var previous: RefCounted = live.exchange_world(candidate.world)
	if view != null:
		var complete: bool = view.attach_loaded_world(live.units,live.sheet_by_unit)
		if force_view_failure_after_attach or not complete:
			live.exchange_world(previous)
			view.rollback_world_nodes(presentation)
			candidate.dispose(); return false
		view.commit_world_nodes(presentation)
		view.finish_loaded_world(live.units,live.game_end)
	live.scene.reset_transients()
	live.cmd_pending = ""
	live.cmd_pending_data = {}
	live.visibility.set_full_reveal(live.cheat_reveal)
	live.commands.session._set_cheat_input(false)
	candidate.world = null
	candidate.saver = null
	previous.dispose()
	return true

func apply_legacy(live: Node2D, old: Dictionary, records: Array, version: int) -> bool:
	var game: Node = live.get_node("/root/Game")
	if not Fields.omissions(live.state).is_empty(): return false
	var validator = preload("res://app/saves/snapshot_validator.gd").new(live, live.saver.content_revision, live.saver._valid_cost, live.saver._valid_integer)
	var candidate = preload("res://app/saves/legacy_seed.gd").create(live)
	if candidate==null: return false
	if not candidate.saver.restore_legacy(old,records,version):
		candidate.dispose(); return false
	candidate.state.nav.set_resources(candidate.state.decor_targets)
	candidate.state.nav.rebuild_buildings(candidate.state.units)
	candidate.state.visibility.update(candidate.state.units,candidate.state.player_owner)
	var resources := {"gold":candidate.state.gold,"wood":candidate.state.wood,"food":candidate.state.food,"stone":candidate.state.stone}
	var normalized: Dictionary = game.snapshot(candidate.state.units,resources,candidate.saver.save_extra())
	normalized.map = str(live.map_id)
	if validator.prepare(normalized,normalized.units).is_empty():
		candidate.dispose(); return false
	return _install(live,candidate)
