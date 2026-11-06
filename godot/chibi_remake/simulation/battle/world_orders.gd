extends RefCounted
## world orders: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/world_orders_dependencies.gd")
var battle: State
var ports := Dependencies.new()

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
	ports._reset_jimou()
	battle.duel_pending = false

func _order_context(pos: Vector2) -> void:
	if battle._input_command and not battle.player_commands.executing:
		_queue_world_order(pos,true);return
	_execute_order_context(pos)

func _execute_order_context(pos: Vector2) -> void:
	_clear_pending()
	var site := ports._own_object_at(pos)
	if not site.is_empty() and bool(site.get("site", false)) and battle.command_rules.allows_context(16139):
		ports._order_build(site)
		return
	var resource := ports._resource_at(pos)
	if not resource.is_empty() and battle.command_rules.allows_context(16138):
		ports._order_gather(resource)
		return
	_order_at(pos)

func _order_at(pos: Vector2) -> void:
	if battle._input_command and not battle.player_commands.executing:
		_queue_world_order(pos,false);return
	_execute_order_at(pos)

func _execute_order_at(pos: Vector2) -> void:
	# **待选目标的命令优先**（原版：先点面板按钮，再点地图目标；jimou/duel 同一模型）。
	if cmd_pending_kind() != "":
		_resolve_pending(pos)
		return
	var tgt := ports._enemy_at(pos)
	if not tgt.is_empty() and battle.command_rules.allows_context(16131):
		_attack_selected(tgt)
		return
	var own := ports._own_object_at(pos)
	if not own.is_empty() and bool(own.get("site", false)) and battle.command_rules.allows_context(16139):
		ports._order_build(own)
		return
	# 武将/带将部队可攻击中立民居/资源建筑获取经验；工人单独选中仍走采集/移动。
	var neutral := ports._neutral_object_at(pos)
	if not neutral.is_empty() and battle.command_rules.allows_context(16131) and _selected_has_nonworker_attacker() and not _selected_has_worker():
		_attack_selected(neutral)
		return
	# 右键点在资源点上、且选中里有工人 → 采集/运输（优先于"走过去"）
	var robj := ports._resource_at(pos)
	if not robj.is_empty() and battle.command_rules.allows_context(16138):
		ports._order_gather(robj)
		return
	_move_selected_to(pos)

func _resolve_pending(pos: Vector2) -> void:
	match cmd_pending_kind():
		"jimou":
			ports._jimou_cast_at(pos)
		"duel":
			ports._duel_at(pos)
		"move":
			_clear_pending()
			_move_selected_to(pos)
		"attack":
			var tgt := ports._attack_target_at(pos)
			if tgt.is_empty():
				ports._feedback("请选择敌方单位、建筑或可摧毁的民房")
				return
			_clear_pending()
			_attack_selected(tgt)
		"transport":
			var site := ports._own_object_at(pos)
			if not site.is_empty() and bool(site.get("site", false)):
				_clear_pending()
				ports._order_build(site)
				return
			var robj := ports._resource_at(pos)
			if robj.is_empty():
				ports._feedback("运输需要点资源点（铁矿／民居／树林／粮堆）")
				return
			_clear_pending()
			ports._order_gather(robj)
		"repair":
			var own := ports._own_object_at(pos)
			if own.is_empty():
				ports._feedback("修理需要点我方单位或建筑")
				return
			_clear_pending()
			ports._order_repair(own)
		"build":
			var opt: Dictionary = battle.cmd_pending_data
			if ports._build_site_at(pos, opt): _clear_pending()
		"board":
			_clear_pending()
			ports._cmd_board_at(pos)
		"join":
			var own := ports._own_object_at(pos)
			if ports._order_join(own) > 0: _clear_pending()
		"unload":
			_clear_pending()
			ports._cmd_unload_at(pos)
		_:
			_clear_pending()

func _selected_has_worker() -> bool:
	for u in battle.selected:
		if ports._is_worker_unit(u): return true
	return false

func _selected_has_nonworker_attacker() -> bool:
	for u in battle.selected:
		if not bool(u.get("alive", false)) or u.die_t >= 0.0 or bool(u.get("is_building", false)) or bool(u.get("attached", false)) or int(u.owner) != battle.player_owner: continue
		if ports._is_worker_unit(u) or not preload("res://simulation/systems/combat_rules.gd").can_attack(u): continue
		if not (u.get("officer", {}) as Dictionary).is_empty() or int(u.get("group_officer", -1)) >= 0: return true
	return false

func _attack_selected(tgt: Dictionary) -> int:
	if tgt.is_empty():
		ports._feedback("这里没有敌方单位")
		return 0
	var n := 0
	for u in ports._command_units():
		if not bool(u.get("alive", false)) or u.die_t >= 0 or bool(u.is_building) or bool(u.get("attached", false)) or int(u.owner) != battle.player_owner:
			continue
		if not preload("res://simulation/systems/combat_rules.gd").can_attack(u): continue
		ports._cancel_unit_command(u)
		u["hold"] = false
		u["state"] = "attack"
		u["target"] = tgt
		u["repath"] = 0.0
		n += 1
	if n == 0: ports._feedback("所选单位没有可用的攻击能力")
	return n

func _move_selected_to(pos: Vector2) -> void:
	var actors: Array = ports._command_units()
	var shared: Array = []
	var shared_from := Vector2i(-9999, -9999)
	var shared_layer := -1
	var shared_class := -1
	if not actors.is_empty():
		var lead: Dictionary = actors[0]
		if bool(lead.get("alive", false)) and not bool(lead.is_building) and int(lead.get("site_inside_uid", -1)) < 0:
			shared_layer=ports._nav_layer(lead)
			shared_class=preload("res://simulation/systems/unit_footprint.gd").class_of(int(lead.get("unit", -1)))
			shared_from = battle.nav.near_walkable(ports._cell_of_px(lead.ax, lead.ay),shared_layer)
			shared = ports._path_to(lead, pos, true)
	var click_cell := ports._cell_of_px(pos.x, pos.y)
	var ok_count := 0
	var fail_count := 0
	var reserved := {}
	for u in actors:
		if not bool(u.get("alive", false)) or u.die_t >= 0 or bool(u.is_building) or bool(u.get("attached", false)) or int(u.owner) != battle.player_owner:
			continue
		ports._cancel_unit_command(u)
		u["hold"] = false
		var target_pos := pos
		var offset_moved := false
		if int(u.get("formation", -1)) >= 0:
			target_pos = ports._anchor_of_cell(ports._formation_target_cell(u, click_cell))
			offset_moved = true
		if actors.size()>1:
			target_pos=ports._march_destination(u,target_pos,reserved)
			offset_moved=offset_moved or not target_pos.is_equal_approx(pos)
		var layer:=ports._nav_layer(u)
		var unit_class:=preload("res://simulation/systems/unit_footprint.gd").class_of(int(u.get("unit", -1)))
		var mine := battle.nav.near_walkable(ports._cell_of_px(u.ax, u.ay),layer)
		var p: Array
		# R04：只有起点、层、占格档都相同的单位才能复用同一条整块路径。
		if layer==shared_layer and unit_class==shared_class and mine == shared_from and not offset_moved:
			p = shared.duplicate()          # 起点一致，可以安全复用
		else:
			p = ports._path_to(u, target_pos, true)   # 起点不同 → 必须自己算
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
		ports._feedback("无法到达那里")
	elif fail_count > 0:
		ports._feedback("%d 个单位无法到达" % fail_count)

func _context_mode(pos: Vector2, use_pending := true) -> int:
	var modes := {"move":2,"attack":1,"transport":7,"build":8,"repair":9,"board":12,"unload":13,"join":15,"jimou":5,"duel":11}
	var kind := cmd_pending_kind()
	if use_pending and kind != "": return int(modes.get(kind,2))
	var site := ports._own_object_at(pos)
	if not site.is_empty() and bool(site.get("site",false)) and battle.command_rules.allows_context(16139):return 8
	if not ports._resource_at(pos).is_empty() and battle.command_rules.allows_context(16138): return 7
	return 1 if not ports._attack_target_at(pos).is_empty() and battle.command_rules.allows_context(16131) else 2

func _queue_world_order(pos: Vector2, context: bool) -> void:
	var mode := _context_mode(pos,not context)
	var target: Dictionary={}
	if mode==7:
		var site := ports._own_object_at(pos)
		if bool(site.get("site",false)):mode=8
	match mode:
		1:target=ports._attack_target_at(pos)
		7:target=ports._resource_at(pos)
		8,9,15:target=ports._own_object_at(pos)
	if mode==8 and not bool(target.get("site",false)):target={}
	var action: Callable=(_execute_order_context if context else _execute_order_at).bind(pos)
	if not target.is_empty():action=_execute_target_command.bind(mode,target)
	battle.player_commands.submit(mode,action,pos,int(target.get("uid",-1)))

func _execute_target_command(mode: int, target: Dictionary) -> void:
	if not bool(target.get("alive",true)) or float(target.get("die_t",-1))>=0:return
	if mode==15:
		if ports._order_join(target)>0:_clear_pending()
		return
	_clear_pending()
	match mode:
		1:_attack_selected(target)
		7:ports._order_gather(target)
		8:ports._order_build(target)
		9:ports._order_repair(target)
