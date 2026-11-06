extends RefCounted
## command groups: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/command_groups_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _group_units(n: int) -> Array:
	var out: Array = []
	var ids: Array = battle.control_groups.get(n, [])
	for u in battle.units:
		if u.alive and u.die_t<0 and int(u.owner)==battle.player_owner and not bool(u.get("attached",false)) and int(u.uid) in ids:
			out.append(u)
	return out

func control_group_size(n: int) -> int:
	return _group_units(n).size()

func control_group_leader(n: int) -> Dictionary:
	var group := _group_units(n)
	for u in group:
		if not bool(u.get("is_building", false)) and not (u.get("officer", {}) as Dictionary).is_empty():
			return u
	return group[0] if not group.is_empty() else {}

func control_group_work_site(n: int) -> Dictionary:
	for member in _group_units(n):
		var site_id := int(member.get("site_inside_uid", -1))
		if site_id < 0: site_id = int(member.get("site_follow_uid", -1))
		if site_id >= 0:
			var site: Dictionary = battle.construction.site_for(site_id)
			if battle.construction.active(site): return site
	return {}

func _group_assign(n: int) -> void:
	var ids: Array = []
	for u in battle.selected:
		if u.alive and u.die_t<0 and int(u.owner)==battle.player_owner and not bool(u.get("attached",false)):ids.append(int(u.uid))
	battle.control_groups[n] = ids
	print("编队 %d：%d 个单位" % [n, ids.size()])

func _group_recall(n: int) -> bool:
	var g := _group_units(n)
	if g.is_empty():
		return false
	var leader := control_group_leader(n)
	if not leader.is_empty():
		var at := g.find(leader)
		if at > 0:
			g.remove_at(at)
			g.push_front(leader)
	battle.selected.clear()
	for u in g:
		battle.selected.append(u)
	if battle.effects != null: battle.effects.sound("play_select", [battle.selected])
	print("呼出编队 %d：%d 个单位" % [n, g.size()])
	return true

func _cmd_watch() -> void:
	var n := 0
	for u in _command_units():
		if u.is_building or not u.alive or u.die_t>=0 or int(u.owner)!=battle.player_owner or bool(u.get("attached",false)):
			continue
		_cancel_unit_command(u)
		u["hold"] = true
		n += 1
	if n > 0:
		ports._feedback("警戒：%d 支部队取消命令、原地待命" % n)
	else:
		ports._feedback("没有可警戒的部队")

func _cancel_unit_command(u: Dictionary) -> void:
	battle.construction.leave(u)
	u["site_follow_uid"] = -1
	preload("res://simulation/systems/action_clock.gd").reset(u)
	u["state"] = "idle"
	u["target"] = null
	u["path"] = []
	u["pi"] = 0
	u["gather_obj"] = null
	u["repair_target"] = null
	u["build_target"] = null
	u["board_target"] = null
	u["join_target_uid"] = -1
	u["cool"] = 0.0
	u["repath"] = 0.0
	u["blocked_n"] = 0
	u["stuck_t"] = 0.0
	u["anim"] = 0.0
	u["hold"] = false
	u.erase("repath_to")
	u["gather_t"] = 0.0
	u["gather_ticks"] = 0
	u["delivery_ticks"] = 0
	u["rest_t"] = 0
	u["build_t"] = 0

func _order_hold() -> void:
	_cmd_watch()

func _cmd_rest() -> void:
	var n := 0
	for u in battle.selected:
		if u.is_building or not u.alive or u.die_t >= 0.0 or int(u.owner)!=battle.player_owner or bool(u.get("attached",false)):
			continue
		if not _is_hero_unit(u):
			continue
		_cancel_unit_command(u)
		u["state"] = "rest"
		u["rest_t"] = 0
		n += 1
	if n > 0:
		ports._feedback("休息：%d 支将部队原地休整（每 10 tick +1 兵力）" % n)
	else:
		ports._feedback("只有武将部队可以休整")

func _is_hero_unit(u: Dictionary) -> bool:
	return int(u.get("unit", -1)) in Config.HERO_UNITS

func _construction_workers(commander: Dictionary) -> Array:
	if commander.is_empty() or not battle.units.has(commander) or not commander.alive or commander.die_t >= 0 or commander.get("attached", false) or not _is_hero_unit(commander) or commander.get("officer", {}).is_empty(): return []
	var index := int(commander.officer.index)
	var members: Array = battle.units.filter(func(u): return u.alive and u.die_t < 0 and not u.is_building and int(u.owner) == int(commander.owner) and int(u.get("group_officer", -1)) == index and u != commander)
	if members.is_empty() or members.size() > Config.TEAM_MAX_MEMBERS or not members.all(func(u): return ports._is_worker_unit(u)): return []
	return members.filter(func(u): return preload("res://simulation/systems/unit_rules.gd").can_build(u) and not u.get("attached", false))

func _selected_construction_workers() -> Array:
	var workers := []
	for unit in battle.selected:
		if not unit.alive or unit.die_t >= 0 or unit.owner != battle.player_owner or unit.get("attached", false): continue
		if unit.get("officer",{}).is_empty():continue
		for worker in _construction_workers(_commander_for(unit)):
			if worker not in workers: workers.append(worker)
	return workers

func _enforce_team_limits() -> void:
	for commander in battle.units:
		if not commander.alive or commander.die_t >= 0 or commander.get("officer", {}).is_empty(): continue
		var members: Array = battle.units.filter(func(u): return u.alive and u.die_t < 0 and not u.is_building and u != commander and int(u.owner) == int(commander.owner) and int(u.get("group_officer", -1)) == int(commander.officer.index))
		members.sort_custom(func(a,b): return int(a.uid) < int(b.uid))
		for i in range(Config.TEAM_MAX_MEMBERS, members.size()):
			var member: Dictionary = members[i]
			member.group_officer = -1
			if member.state == "build": _cancel_unit_command(member)

func _is_naval(u: Dictionary) -> bool:
	return int(u.get("unit", -1)) in Config.NAVAL_UNITS

func _nav_layer(u: Dictionary) -> int:
	return 1 if _is_naval(u) and battle.nav.has_water else 0

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	if battle.selected.is_empty():
		ports._feedback("先选择部队")
		return
	if kind=="unload":
		ports._clear_pending()
		battle.player_commands.submit(13,ports._unload_selected)
		return
	if battle.cmd_pending == kind:
		ports._clear_pending()
		ports._feedback("已取消")
		return
	ports._reset_jimou()
	battle.duel_pending = false
	battle.cmd_pending = kind
	battle.cmd_pending_data = data
	match kind:
		"move": ports._feedback("移动：点击目的地")
		"attack": ports._feedback("攻击：点击敌方单位")
		"transport": ports._feedback("运输：点击资源点（铁矿／民居／树林／粮堆）")
		"repair": ports._feedback("修理：点击我方单位或建筑（四资源各 −16）")
		"build": ports._feedback("建造：点击空地放下工地（%s）" % str(data.get("name", "?")))
		"board": ports._feedback("上船：点击我方运输船（陆军靠近后自动装载）")
		"join": ports._feedback("加入：点击我方带将队伍，工人靠近后编入（每队最多15名成员）")
		_: ports._feedback("选择目标")

func _cmd_disband() -> void:
	var n := ports._order_disband()
	if n <= 0:
		ports._feedback("请选择武将部队")

func _commander_for(u: Dictionary) -> Dictionary:
	if not u.get("officer", {}).is_empty(): return u
	var index := int(u.get("group_officer", -1))
	for other in battle.units:
		if other.alive and other.die_t < 0 and int(other.owner) == int(u.owner) and int(other.get("officer", {}).get("index", -2)) == index: return other
	return {}

func _command_units() -> Array:
	var result: Array=battle.selected.duplicate()
	for leader in battle.selected:
		if leader.get("officer",{}).is_empty():continue
		for member in battle.units:
			if member.alive and member.die_t<0 and int(member.owner)==int(leader.owner) and int(member.get("group_officer",-1))==int(leader.officer.index) and member not in result:result.append(member)
	return result

func _return_selected_cargo() -> void:
	var count:=0
	for worker in battle.selected:
		if not ports._is_worker_unit(worker) or float(worker.get("carry",0))<=0:continue
		var resource=worker.get("gather_obj")
		_cancel_unit_command(worker)
		worker.gather_obj=resource;worker.state="deliver";count+=1
	ports._feedback("%d 名工人返回入库" % count)

func stop_selected() -> void:
	var count := 0
	for u in battle.selected:
		if not u.alive or u.is_building:
			continue
		_cancel_unit_command(u)
		count += 1
	if count > 0:
		ports._feedback("停止")
