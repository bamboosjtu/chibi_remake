extends RefCounted
## Command admission and application at the world's fixed tick boundary.
signal commands_applied
signal command_finished(command: Dictionary, result: String)
const CAPACITY := 64
const State = preload("res://simulation/battle_state.gd")
const REQUIRED_SERVICES := {"abilities": ["_cast_jimou", "_set_formation", "_start_duel"], "battle_simulation": ["_feedback"], "command_groups": ["_cmd_disband", "_cmd_rest", "_cmd_watch", "_group_assign", "_return_selected_cargo", "stop_selected"], "construction_orders": ["_build_site_at", "_cancel_site", "_order_build", "_order_repair", "ai_place_building"], "harvest_orders": ["_order_gather"], "officer_teams": ["_order_form_up", "_order_join"], "production": ["_cancel_training", "_order_train", "_queue_train"], "spatial_index": ["unit_by_uid"], "technology": ["_cancel_tech", "_queue_research", "_start_tech"], "transport_orders": ["_order_board", "_unload_selected"], "world_orders": ["_attack_selected", "_attack_units", "_clear_pending", "_move_autonomous", "_move_selected_to"]}
const KINDS := ["move","attack","gather","continue_build","build","repair","train","research","cancel_research",
	"watch","rest","stop","disband","assign_officer","assign_group","join","return_cargo","board","unload",
	"formation","jimou","duel","cancel_site","cancel_train"]
var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)
var _state: WeakRef
var _world_id: int
var _pending: Array[Dictionary] = []
var _slots := 0
var sequence := 0

func _init(battle: State, world_id: int) -> void:
	_state = weakref(battle)
	_world_id = world_id

func submit(kind: String, selection: Array, position := Vector2.ZERO, uid := -1, parameter := -1, cell := "") -> int:
	var battle: State = _state.get_ref()
	if battle == null or battle.game_end != 0 or kind not in KINDS or not position.is_finite(): return 0
	var actors := selection.filter(func(unit): return _eligible(unit, battle.player_owner))
	if kind in ["jimou","formation","duel"]:
		var leader: Dictionary = battle.command_rules.selected_leader(actors)
		actors = [leader] if not leader.is_empty() else actors.slice(0, 1)
	var uids: Array[int] = []
	for unit in actors:
		var actor_uid := int(unit.uid)
		if uids.size() + _slots >= CAPACITY: break
		if not uids.has(actor_uid): uids.append(actor_uid)
	if uids.size() < actors.size(): _feedback("指令任务表已满，部分单位未接到指令")
	if uids.is_empty(): return 0
	_pending.append(_make_command(kind, "player", battle.player_owner, uids, position, uid, parameter, cell, battle.sim_tick + 1))
	_slots += uids.size()
	return uids.size()

func _make_command(kind: String, source: String, owner: int, uids: Array, position: Vector2, uid: int, parameter: int, cell: String, tick: int) -> Dictionary:
	sequence += 1
	return preload("res://simulation/definitions/frozen_data.gd").copy({
		"kind":kind, "source":source, "owner":owner, "actors":uids, "position":[position.x,position.y],
		"target_uid":uid, "parameter":parameter, "cell":cell, "tick":tick, "sequence":sequence, "world_id":_world_id,
	})

func has_pending() -> bool:
	return not _pending.is_empty()

func pending_commands() -> Array:
	return _pending.duplicate()

func apply_tick(tick: int) -> int:
	var applied := 0
	var ready := _pending
	_pending = []
	_slots = 0
	for command in ready:
		if int(command.tick) > tick:
			_pending.append(command)
			_slots += command.actors.size()
			continue
		var result := _apply(command)
		if result == "applied": applied += 1
		command_finished.emit(command, result)
	if applied > 0: commands_applied.emit()
	return applied

func apply_autonomous(kind: String, owner: int, actor_uid: int, target_uid := -1, parameter := -1, cell := "", position := Vector2.ZERO) -> bool:
	var battle: State = _state.get_ref()
	if battle == null or kind not in ["move", "attack", "gather", "train", "research", "build"]: return false
	var source := "auto_control" if owner == battle.player_owner else "ai"
	var command := _make_command(kind, source, owner, [actor_uid], position, target_uid, parameter, cell, battle.sim_tick)
	return _apply(command) == "applied"

func clear() -> void:
	_pending.clear()
	_slots = 0

func _eligible(unit: Dictionary, owner: int) -> bool:
	return bool(unit.get("alive",false)) and float(unit.get("die_t",-1)) < 0 and int(unit.get("owner",-1)) == owner

func _feedback(message: String) -> void:
	var services := ports.acquire(["battle_simulation"])
	if services.is_empty(): return
	services.battle_simulation._feedback(message)

func _apply(command: Dictionary) -> String:
	var battle: State = _state.get_ref()
	if battle == null or int(command.world_id) != _world_id or battle.game_end != 0: return "stale_world"
	var services := ports.acquire(["spatial_index"])
	if services.is_empty(): return "unavailable"
	var actors: Array = []
	for uid in command.actors:
		var actor: Dictionary = services.spatial_index.unit_by_uid(int(uid))
		if _eligible(actor, int(command.owner)): actors.append(actor)
	if actors.is_empty(): return "stale_actors"
	var target: Dictionary = {}
	if not str(command.cell).is_empty(): target = battle.decor_cells.get(command.cell, {})
	elif int(command.target_uid) >= 0: target = services.spatial_index.unit_by_uid(int(command.target_uid))
	if not str(command.cell).is_empty() or int(command.target_uid) >= 0:
		if target.is_empty() or not target.get("alive", false) or float(target.get("die_t", -1)) >= 0:
			_feedback("目标已失效")
			return "stale_target"
	if _apply_order(command, battle, actors, target): return "applied"
	return "rejected"

func _apply_order(command: Dictionary, battle: State, actors: Array, target: Dictionary) -> bool:
	var services := ports.acquire(["abilities", "command_groups", "construction_orders", "harvest_orders", "officer_teams", "production", "technology", "transport_orders", "world_orders"])
	if services.is_empty(): return false
	var pos := Vector2(float(command.position[0]), float(command.position[1]))
	var parameter := int(command.parameter)
	var owner := int(command.owner)
	match str(command.kind):
		"move":
			if command.source != "player": return services.world_orders._move_autonomous(actors[0], pos)
			return services.world_orders._move_selected_to(pos, actors) > 0
		"attack":
			if target.is_empty() or int(target.owner) == owner: return false
			if command.source != "player": return services.world_orders._attack_units(actors, target, owner) > 0
			return services.world_orders._attack_selected(target, actors) > 0
		"gather": return services.harvest_orders._order_gather(target, actors, owner) > 0
		"continue_build": return services.construction_orders._order_build(target, actors) > 0
		"repair": return services.construction_orders._order_repair(target, actors) > 0
		"build":
			if command.source != "player": return services.construction_orders.ai_place_building(owner, parameter, actors[0])
			for option in battle.build_types:
				if int(option.unit) == parameter:
					if not services.construction_orders._build_site_at(pos, option, actors): return false
					if battle.cmd_pending == "build" and int(battle.cmd_pending_data.get("unit", -1)) == parameter:
						services.world_orders._clear_pending()
					return true
			return false
		"train":
			if command.source != "player": return services.production._queue_train(owner, actors[0], parameter)
			return services.production._order_train(parameter, actors)
		"research":
			if command.source != "player": return services.technology._queue_research(owner, actors[0], parameter, true)
			return services.technology._start_tech(parameter, actors)
		"cancel_research": return services.technology._cancel_tech(actors)
		"cancel_site", "cancel_train":
			if target.is_empty() or int(target.owner) != owner or target not in actors: return false
			if command.kind == "cancel_site": return services.construction_orders._cancel_site(target)
			return services.production._cancel_training(target)
		"join":
			if services.officer_teams._order_join(target, actors) == 0: return false
			if battle.cmd_pending == "join": services.world_orders._clear_pending()
		"board": return services.transport_orders._order_board(target, actors) > 0
		"jimou":
			if parameter == 8: target = {"ax":pos.x,"ay":pos.y,"name":"地面","ground":true,"owner":-1}
			if not services.abilities._cast_jimou(pos, parameter, actors[0], target): return false
			if battle.jimou_pending == parameter and is_same(battle.jimou_caster, actors[0]): services.world_orders._clear_pending()
		"duel": return services.abilities._start_duel(actors[0], target)
		"formation": services.abilities._set_formation(parameter, actors)
		"unload": services.transport_orders._unload_selected(actors)
		"watch": services.command_groups._cmd_watch(actors)
		"rest": services.command_groups._cmd_rest(actors)
		"stop": services.command_groups.stop_selected(actors)
		"disband": services.command_groups._cmd_disband(actors)
		"assign_officer": services.officer_teams._order_form_up(parameter, actors)
		"assign_group": services.command_groups._group_assign(parameter, actors)
		"return_cargo": services.command_groups._return_selected_cargo(actors)
		_: return false
	return true
