extends Object
var _player_commands: RefCounted
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _command_rules: RefCounted
## world orders: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_abilities: Object
var _dep_command_groups: Object
var _dep_construction_orders: Object
var _dep_harvest_orders: Object
var _dep_movement: Object
var _dep_officer_teams: Object
var _dep_selection: Object
var _dep_technology: Object
var _dep_transport_orders: Object

func _init(data: State) -> void:
	battle = data

func cmd_pending_kind() -> String:
	if battle.jimou_pending >= 0:
		return "jimou"
	if battle.duel_pending:
		return "duel"
	return battle.cmd_pending

func _clear_pending() -> void:
	battle.cmd_pending = ""
	battle.cmd_pending_data = {}
	_dep_abilities._reset_jimou()
	battle.duel_pending = false

func _order_context(pos: Vector2) -> void:
	_execute_order_context(pos)

func _execute_order_context(pos: Vector2) -> void:
	_clear_pending()
	var site: Dictionary = _dep_selection._own_object_at(pos)
	if not site.is_empty() and bool(site.get("site", false)) and _command_rules.allows_context(16139):
		_dep_construction_orders._order_build(site)
		return
	var resource: Dictionary = _dep_harvest_orders._resource_at(pos)
	if not resource.is_empty() and _command_rules.allows_context(16138):
		_dep_harvest_orders._order_gather(resource)
		return
	_order_at(pos)

func _order_at(pos: Vector2) -> void:
	_execute_order_at(pos)

func _execute_order_at(pos: Vector2) -> void:
	# **待选目标的命令优先**（原版：先点面板按钮，再点地图目标；jimou/duel 同一模型）。
	if cmd_pending_kind() != "":
		_resolve_pending(pos)
		return
	var tgt: Dictionary = _dep_selection._enemy_at(pos)
	if not tgt.is_empty() and _command_rules.allows_context(16131):
		_attack_selected(tgt)
		return
	var own: Dictionary = _dep_selection._own_object_at(pos)
	if not own.is_empty() and bool(own.get("site", false)) and _command_rules.allows_context(16139):
		_dep_construction_orders._order_build(own)
		return
	# 武将/带将部队可攻击中立民居/资源建筑获取经验；工人单独选中仍走采集/移动。
	var neutral: Dictionary = _dep_selection._neutral_object_at(pos)
	if not neutral.is_empty() and _command_rules.allows_context(16131) and _selected_has_nonworker_attacker() and not _selected_has_worker():
		_attack_selected(neutral)
		return
	# 右键点在资源点上、且选中里有工人 → 采集/运输（优先于"走过去"）
	var robj: Dictionary = _dep_harvest_orders._resource_at(pos)
	if not robj.is_empty() and _command_rules.allows_context(16138):
		_dep_harvest_orders._order_gather(robj)
		return
	_move_selected_to(pos)

func _resolve_pending(pos: Vector2) -> void:
	match cmd_pending_kind():
		"jimou":
			_dep_abilities._jimou_cast_at(pos)
		"duel":
			submit_point_order(pos, false)
		"move":
			_clear_pending()
			_move_selected_to(pos)
		"attack":
			var tgt: Dictionary = _dep_selection._attack_target_at(pos)
			if tgt.is_empty():
				_effects.feedback("请选择敌方单位、建筑或可摧毁的民房")
				return
			_clear_pending()
			_attack_selected(tgt)
		"transport":
			var site: Dictionary = _dep_selection._own_object_at(pos)
			if not site.is_empty() and bool(site.get("site", false)):
				_clear_pending()
				_dep_construction_orders._order_build(site)
				return
			var robj: Dictionary = _dep_harvest_orders._resource_at(pos)
			if robj.is_empty():
				_effects.feedback("运输需要点资源点（铁矿／民居／树林／粮堆）")
				return
			_clear_pending()
			_dep_harvest_orders._order_gather(robj)
		"repair":
			var own: Dictionary = _dep_selection._own_object_at(pos)
			if own.is_empty():
				_effects.feedback("修理需要点我方单位或建筑")
				return
			_clear_pending()
			_dep_construction_orders._order_repair(own)
		"build":
			var opt: Dictionary = battle.cmd_pending_data
			if _dep_construction_orders._build_site_at(pos, opt): _clear_pending()
		"board":
			_clear_pending()
			_dep_transport_orders._cmd_board_at(pos)
		"join":
			var own: Dictionary = _dep_selection._own_object_at(pos)
			if _dep_officer_teams._order_join(own) > 0: _clear_pending()
		"unload":
			_clear_pending()
			_dep_transport_orders._cmd_unload_at(pos)
		_:
			_clear_pending()

func _selected_has_worker() -> bool:
	for u in battle.selected:
		if _dep_technology._is_worker_unit(u): return true
	return false

func _selected_has_nonworker_attacker() -> bool:
	for u in battle.selected:
		if not bool(u.get("alive", false)) or u.die_t >= 0.0 or bool(u.get("is_building", false)) or bool(u.get("attached", false)) or int(u.owner) != battle.player_owner: continue
		if _dep_technology._is_worker_unit(u) or not preload("res://simulation/systems/combat_rules.gd").can_attack(u): continue
		if not (u.get("officer", {}) as Dictionary).is_empty() or int(u.get("group_officer", -1)) >= 0: return true
	return false

func _attack_selected(tgt: Dictionary, selected = null) -> int:
	if tgt.is_empty():
		_effects.feedback("这里没有敌方单位")
		return 0
	var count := _attack_units(_dep_command_groups._command_units(selected), tgt, battle.player_owner)
	if count == 0: _effects.feedback("所选单位没有可用的攻击能力")
	return count

func _attack_units(actors: Array, target: Dictionary, owner: int) -> int:
	if target.is_empty() or not target.alive or target.die_t >= 0 or target.owner == owner: return 0
	if target.get("attached", false) or int(target.get("site_inside_uid", -1)) >= 0: return 0
	var count := 0
	for unit in actors:
		if not unit.alive or unit.die_t >= 0 or unit.is_building or unit.get("attached", false) or int(unit.owner) != owner:
			continue
		if not preload("res://simulation/systems/combat_rules.gd").can_attack(unit): continue
		_dep_command_groups._cancel_unit_command(unit)
		unit["state"] = "attack"
		unit["target"] = target
		count += 1
	return count

func _move_autonomous(unit: Dictionary, position: Vector2) -> bool:
	if unit.is_building or unit.get("attached", false): return false
	var path: Array = _dep_movement._path_to(unit, position, true)
	if path.is_empty(): return false
	_dep_command_groups._cancel_unit_command(unit)
	unit.state = "move"
	unit.path = path
	return true

func _move_selected_to(pos: Vector2, selected = null) -> int:
	var actors: Array = _dep_command_groups._command_units(selected)
	var shared: Array = []
	var shared_from := Vector2i(-9999, -9999)
	var shared_layer := -1
	var shared_class := -1
	if not actors.is_empty():
		var lead: Dictionary = actors[0]
		if bool(lead.get("alive", false)) and not bool(lead.is_building) and int(lead.get("site_inside_uid", -1)) < 0:
			shared_layer=_dep_command_groups._nav_layer(lead)
			shared_class=preload("res://simulation/systems/unit_footprint.gd").class_of(int(lead.get("unit", -1)))
			shared_from = _nav.near_walkable(_dep_movement._cell_of_px(lead.ax, lead.ay),shared_layer)
			shared = _dep_movement._path_to(lead, pos, true)
	var click_cell: Vector2i = _dep_movement._cell_of_px(pos.x, pos.y)
	var ok_count := 0
	var fail_count := 0
	var reserved := {}
	for u in actors:
		if not bool(u.get("alive", false)) or u.die_t >= 0 or bool(u.is_building) or bool(u.get("attached", false)) or int(u.owner) != battle.player_owner:
			continue
		_dep_command_groups._cancel_unit_command(u)
		u["hold"] = false
		var target_pos := pos
		var offset_moved := false
		if int(u.get("formation", -1)) >= 0:
			target_pos = _dep_movement._anchor_of_cell(_dep_abilities._formation_target_cell(u, click_cell))
			offset_moved = true
		if actors.size()>1:
			target_pos=_dep_movement._march_destination(u,target_pos,reserved)
			offset_moved=offset_moved or not target_pos.is_equal_approx(pos)
		var layer: int = _dep_command_groups._nav_layer(u)
		var unit_class:=preload("res://simulation/systems/unit_footprint.gd").class_of(int(u.get("unit", -1)))
		var mine := _nav.near_walkable(_dep_movement._cell_of_px(u.ax, u.ay),layer)
		var p: Array
		# R04：只有起点、层、占格档都相同的单位才能复用同一条整块路径。
		if layer==shared_layer and unit_class==shared_class and mine == shared_from and not offset_moved:
			p = shared.duplicate()          # 起点一致，可以安全复用
		else:
			p = _dep_movement._path_to(u, target_pos, true)   # 起点不同 → 必须自己算
		if p.is_empty():
			u["state"] = "idle"
			u["target"] = null
			u["path"] = []
			u["pi"] = 0
			fail_count += 1
			continue
		u["state"] = "move"
		u["path"] = p
		u["pi"] = 0
		u["target"] = null
		ok_count += 1
	if fail_count > 0 and ok_count == 0:
		_effects.feedback("无法到达那里")
	elif fail_count > 0:
		_effects.feedback("%d 个单位无法到达" % fail_count)
	return ok_count

func _context_mode(pos: Vector2, use_pending := true) -> int:
	var modes := {"move":2,"attack":1,"transport":7,"build":8,"repair":9,"board":12,"unload":13,"join":15,"jimou":5,"duel":11}
	var kind := cmd_pending_kind()
	if use_pending and kind != "": return int(modes.get(kind,2))
	var site: Dictionary = _dep_selection._own_object_at(pos)
	if not site.is_empty() and bool(site.get("site",false)) and _command_rules.allows_context(16139):return 8
	if not _dep_harvest_orders._resource_at(pos).is_empty() and _command_rules.allows_context(16138): return 7
	return 1 if not _dep_selection._attack_target_at(pos).is_empty() and _command_rules.allows_context(16131) else 2

func submit_point_order(pos: Vector2, context: bool) -> int:
	var pending := "" if context else cmd_pending_kind()
	var kind := pending
	var target: Dictionary = {}
	var parameter := -1
	var actors: Array = battle.selected
	match pending:
		"build": parameter = int(battle.cmd_pending_data.get("unit", -1))
		"attack": target = _dep_selection._attack_target_at(pos)
		"repair", "join": target = _dep_selection._own_object_at(pos)
		"transport":
			target = _dep_selection._own_object_at(pos)
			if target.get("site", false): kind = "continue_build"
			else:
				kind = "gather"
				target = _dep_harvest_orders._resource_at(pos)
		"board": target = _dep_transport_orders._own_ship_at(pos)
		"jimou":
			parameter = battle.jimou_pending
			actors = [battle.jimou_caster] if not battle.jimou_caster.is_empty() else []
			target = _dep_abilities.jimou_target_at(pos, parameter)
		"duel":
			var leader: Dictionary = _dep_abilities._jimou_caster_for_selection()
			target = _dep_selection._enemy_at(pos)
			if leader.is_empty() or target.is_empty():
				_clear_pending()
				_effects.feedback("单挑目标必须是将领部队")
				return 0
			actors = [leader]
		"":
			var site: Dictionary = _dep_selection._own_object_at(pos)
			var resource: Dictionary = _dep_harvest_orders._resource_at(pos)
			var enemy: Dictionary = _dep_selection._enemy_at(pos)
			if not context and not enemy.is_empty() and _command_rules.allows_context(16131):
				kind = "attack"; target = enemy
			elif bool(site.get("site", false)) and _command_rules.allows_context(16139):
				kind = "continue_build"; target = site
			elif context and not resource.is_empty() and _command_rules.allows_context(16138):
				kind = "gather"; target = resource
			elif not enemy.is_empty() and _command_rules.allows_context(16131):
				kind = "attack"; target = enemy
			elif _command_rules.allows_context(16131) and _selected_has_nonworker_attacker() and not _selected_has_worker():
				target = _dep_selection._neutral_object_at(pos)
				kind = "move" if target.is_empty() else "attack"
			if kind in ["", "move"]:
				if not resource.is_empty() and _command_rules.allows_context(16138):
					kind = "gather"; target = resource
				else: kind = "move"
	if kind in ["attack", "repair", "join", "board", "duel", "jimou", "gather", "continue_build"] and target.is_empty():
		_effects.feedback("请选择有效目标")
		if kind in ["board", "duel"]: _clear_pending()
		return 0
	if pending in ["build", "jimou", "join"] and _player_commands.pending_commands().any(
			func(command): return command.kind == kind and int(command.parameter) == parameter):
		return 0
	var accepted: int = _player_commands.submit(kind, actors, pos, int(target.get("uid", -1)), parameter, str(target.get("cell", "")))
	if accepted > 0 and (context or pending not in ["build", "jimou", "join"]): _clear_pending()
	return accepted

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_command_groups = world.command_groups
	_dep_construction_orders = world.construction_orders
	_dep_harvest_orders = world.harvest_orders
	_dep_movement = world.movement
	_dep_officer_teams = world.officer_teams
	_dep_selection = world.selection
	_dep_technology = world.technology
	_dep_transport_orders = world.transport_orders
	_command_rules = world.command_rules
	_effects = world.effects
	_nav = world.nav
	_player_commands = world.player_commands
