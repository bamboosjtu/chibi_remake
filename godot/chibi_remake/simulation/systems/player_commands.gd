extends RefCounted
const EffectsRuntime = preload("res://simulation/battle_effects.gd")
var _effects: EffectsRuntime
var _command_rules: RefCounted
## Command admission and application at the world's fixed tick boundary.
signal commands_applied
signal command_finished(command: Dictionary, result: String)
const CAPACITY := 64
const State = preload("res://simulation/battle_state.gd")
const KINDS := ["move","attack","gather","continue_build","build","repair","train","research","cancel_research",
	"watch","rest","stop","disband","assign_officer","assign_group","join","return_cargo","board","unload",
	"formation","jimou","duel","cancel_site","cancel_train"]
var _dep_abilities: Object
var _dep_command_groups: Object
var _dep_construction_orders: Object
var _dep_harvest_orders: Object
var _dep_officer_teams: Object
var _dep_production: Object
var _dep_spatial_index: Object
var _dep_technology: Object
var _dep_transport_orders: Object
var _dep_world_orders: Object
var _state: WeakRef
var _world_id: int
var _pending: Array[Dictionary] = []
var _slots := 0
var sequence := 0

func _init(battle: State, world_id: int) -> void:
	_state = weakref(battle)
	_world_id = world_id

func submit(kind: String, selection: Array, position := Vector2.ZERO, uid := -1, parameter := -1, cell := "") -> int:
	var battle: State = _state.get_ref() if _state != null else null
	if battle == null or battle.game_end != 0 or kind not in KINDS or not position.is_finite(): return 0
	var actors := selection.filter(func(unit): return _eligible(unit, battle.player_owner))
	if kind in ["jimou","formation","duel"]:
		var leader: Dictionary = _command_rules.selected_leader(actors)
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
	var battle: State = _state.get_ref() if _state != null else null
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
	var battle: State = _state.get_ref() if _state != null else null
	_effects.feedback(message)

func _apply(command: Dictionary) -> String:
	var battle: State = _state.get_ref() if _state != null else null
	if battle == null or int(command.world_id) != _world_id or battle.game_end != 0: return "stale_world"
	var actors: Array = []
	for uid in command.actors:
		var actor: Dictionary = _dep_spatial_index.unit_by_uid(int(uid))
		if _eligible(actor, int(command.owner)): actors.append(actor)
	if actors.is_empty(): return "stale_actors"
	var target: Dictionary = {}
	if not str(command.cell).is_empty(): target = battle.decor_cells.get(command.cell, {})
	elif int(command.target_uid) >= 0: target = _dep_spatial_index.unit_by_uid(int(command.target_uid))
	if not str(command.cell).is_empty() or int(command.target_uid) >= 0:
		if target.is_empty() or not target.get("alive", false) or float(target.get("die_t", -1)) >= 0:
			_feedback("目标已失效")
			return "stale_target"
	if _apply_order(command, battle, actors, target): return "applied"
	return "rejected"

func _apply_order(command: Dictionary, battle: State, actors: Array, target: Dictionary) -> bool:
	var pos := Vector2(float(command.position[0]), float(command.position[1]))
	var parameter := int(command.parameter)
	var owner := int(command.owner)
	match str(command.kind):
		"move":
			if command.source != "player": return _dep_world_orders._move_autonomous(actors[0], pos)
			return _dep_world_orders._move_selected_to(pos, actors) > 0
		"attack":
			if target.is_empty() or int(target.owner) == owner: return false
			if command.source != "player": return _dep_world_orders._attack_units(actors, target, owner) > 0
			return _dep_world_orders._attack_selected(target, actors) > 0
		"gather": return _dep_harvest_orders._order_gather(target, actors, owner) > 0
		"continue_build": return _dep_construction_orders._order_build(target, actors) > 0
		"repair": return _dep_construction_orders._order_repair(target, actors) > 0
		"build":
			if command.source != "player": return _dep_construction_orders.ai_place_building(owner, parameter, actors[0])
			for option in battle.build_types:
				if int(option.unit) == parameter:
					if not _dep_construction_orders._build_site_at(pos, option, actors): return false
					if battle.cmd_pending == "build" and int(battle.cmd_pending_data.get("unit", -1)) == parameter:
						_dep_world_orders._clear_pending()
					return true
			return false
		"train":
			if command.source != "player": return _dep_production._queue_train(owner, actors[0], parameter)
			return _dep_production._order_train(parameter, actors)
		"research":
			if command.source != "player": return _dep_technology._queue_research(owner, actors[0], parameter, true)
			return _dep_technology._start_tech(parameter, actors)
		"cancel_research": return _dep_technology._cancel_tech(actors)
		"cancel_site", "cancel_train":
			if target.is_empty() or int(target.owner) != owner or target not in actors: return false
			if command.kind == "cancel_site": return _dep_construction_orders._cancel_site(target)
			return _dep_production._cancel_training(target)
		"join":
			if _dep_officer_teams._order_join(target, actors) == 0: return false
			if battle.cmd_pending == "join": _dep_world_orders._clear_pending()
		"board": return _dep_transport_orders._order_board(target, actors) > 0
		"jimou":
			if parameter == 8: target = {"ax":pos.x,"ay":pos.y,"name":"地面","ground":true,"owner":-1}
			if not _dep_abilities._cast_jimou(pos, parameter, actors[0], target): return false
			if battle.jimou_pending == parameter and is_same(battle.jimou_caster, actors[0]): _dep_world_orders._clear_pending()
		"duel": return _dep_abilities._start_duel(actors[0], target)
		"formation": _dep_abilities._set_formation(parameter, actors)
		"unload": _dep_transport_orders._unload_selected(actors)
		"watch": _dep_command_groups._cmd_watch(actors)
		"rest": _dep_command_groups._cmd_rest(actors)
		"stop": _dep_command_groups.stop_selected(actors)
		"disband": _dep_command_groups._cmd_disband(actors)
		"assign_officer": _dep_officer_teams._order_form_up(parameter, actors)
		"assign_group": _dep_command_groups._group_assign(parameter, actors)
		"return_cargo": _dep_command_groups._return_selected_cargo(actors)
		_: return false
	return true

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_command_groups = world.command_groups
	_dep_construction_orders = world.construction_orders
	_dep_harvest_orders = world.harvest_orders
	_dep_officer_teams = world.officer_teams
	_dep_production = world.production
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_dep_transport_orders = world.transport_orders
	_dep_world_orders = world.world_orders
	_command_rules = world.command_rules
	_effects = world.effects

func move_order(owner: int, uid: int, target: Vector2) -> bool:
	return apply_autonomous("move", owner, uid, -1, -1, "", target)

func _queue_research(owner: int, building: Dictionary, idx: int, _ai_dispatch := false) -> bool:
	return not building.is_empty() and apply_autonomous("research", owner, int(building.uid), -1, idx)

func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	return not building.is_empty() and apply_autonomous("train", owner, int(building.uid), -1, uid)

func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	return not commander.is_empty() and apply_autonomous("build", owner, int(commander.uid), -1, building_type)

func retire() -> void:
	clear()
	_state = null
	for event: Signal in [commands_applied, command_finished]:
		for connection in event.get_connections():
			event.disconnect(connection.callable)
