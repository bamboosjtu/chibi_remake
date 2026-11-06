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
	if force_view_failure:
		candidate.dispose(); return false
	var view = live.view
	var old_nodes: Dictionary = view._ui._nodes_by_uid if view != null else {}
	var old_motion: Dictionary = view._ui._motion_previous if view != null else {}
	var old_gait: Dictionary = view._ui._gait_previous if view != null else {}
	var previous: RefCounted = live.exchange_world(candidate.world)
	if view != null:
		view._ui._nodes_by_uid = {}
		for unit in live.units:
			var sheet: String = str(live.sheet_by_unit.get("%d_%d" % [int(unit.unit), int(unit.owner)], ""))
			view.attach_unit(unit, {"sheet":sheet,"unit":unit.unit,"owner":unit.owner}, int(unit.w),int(unit.h),float(unit.k))
		if force_view_failure_after_attach or not _complete_nodes(view, live.units):
			_free_nodes(view._ui._nodes_by_uid)
			live.exchange_world(previous)
			view._ui._nodes_by_uid = old_nodes
			view._ui._motion_previous = old_motion
			view._ui._gait_previous = old_gait
			candidate.dispose(); return false
		_free_nodes(old_nodes)
		view.capture_motion()
		if view.event_view != null: view.event_view.restore_history()
		for unit in live.units: view.update_visual(unit)
		if view.completion != null:
			view.completion.reset(); view.end_label.hide()
			if live.game_end != 0: view.show_end(live.game_end)
		view.projectile_view.impacts.clear()
		if view.cmd_box_ready(): view.update_panel()
	live.visibility.set_full_reveal(live.cheat_reveal)
	live.commands._set_cheat_input(false)
	candidate.world = null
	candidate.saver = null
	previous.dispose()
	return true

func _complete_nodes(view: Node2D, units: Array) -> bool:
	for unit in units:
		var record: Dictionary = view.unit_nodes(unit)
		if record.get("spr") == null or not is_instance_valid(record.spr): return false
		for key in ["diamond", "hbar"]:
			if record.get(key) == null or not is_instance_valid(record[key]): return false
		if record.spr.texture == null and (record.get("skin") == null or record.skin.texture == null): return false
	return true

func _free_nodes(records: Dictionary) -> void:
	for record in records.values():
		for key in ["spr", "diamond", "hbar"]:
			var node = record.get(key)
			if node != null and is_instance_valid(node): node.queue_free()

func apply_legacy(live: Node2D, old: Dictionary, records: Array, version: int) -> bool:
	var game: Node = live.get_node("/root/Game")
	if not Fields.omissions(live.state).is_empty(): return false
	var seed: Dictionary = game.snapshot(live.units, live.commands._resources(), live.saver.save_extra())
	seed.map = str(live.map_id)
	var validator = preload("res://app/saves/snapshot_validator.gd").new(live, live.saver.content_revision, live.saver._valid_cost, live.saver._valid_integer)
	var plan: Dictionary = validator.prepare(seed,seed.units)
	if plan.is_empty(): return false
	var candidate = preload("res://app/saves/candidate_world.gd").new()
	if not candidate.prepare(live.state,live.world.definition) or not candidate.saver.restore_candidate(seed,seed.units,plan):
		candidate.dispose(); return false
	if not candidate.saver.restore_legacy(old,records,version):
		candidate.dispose(); return false
	var resources := {"gold":candidate.state.gold,"wood":candidate.state.wood,"food":candidate.state.food,"stone":candidate.state.stone}
	var normalized: Dictionary = game.snapshot(candidate.state.units,resources,candidate.saver.save_extra())
	normalized.map = str(live.map_id)
	if validator.prepare(normalized,normalized.units).is_empty():
		candidate.dispose(); return false
	return _install(live,candidate)
