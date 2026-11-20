extends Object
const UnitPath = preload("res://simulation/movement/unit_path.gd")
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _construction: RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## command groups: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_abilities: Object
var _dep_officer_teams: Object
var _dep_technology: Object
var _dep_world_orders: Object

func _init(data: State) -> void:
	battle = data

func _group_units(n: int) -> Array:
	var out: Array = []
	var ids: Array = battle.control_groups.get(n, [])
	if ids.is_empty():return out
	for u in battle.units:
		if int(u.uid) in ids and u.alive and u.die_t<0 and int(u.owner)==battle.player_owner and not bool(u.get("attached",false)):
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
			var site: Dictionary = _construction.site_for(site_id)
			if _construction.active(site): return site
	return {}

func _group_assign(n: int, actors = null) -> bool:
	var ids: Array = []
	for u in battle.selected if actors == null else actors:
		if u.alive and u.die_t<0 and int(u.owner)==battle.player_owner and not bool(u.get("attached",false)):ids.append(int(u.uid))
	battle.control_groups[n] = ids
	print("编队 %d：%d 个单位" % [n, ids.size()])
	return true

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
	if _effects != null: _effects.sound("play_select", [battle.selected])
	print("呼出编队 %d：%d 个单位" % [n, g.size()])
	return true

func _cmd_watch(actors = null) -> bool:
	var n := 0
	for u in _command_units(actors):
		if u.is_building or not u.alive or u.die_t>=0 or int(u.owner)!=battle.player_owner or bool(u.get("attached",false)):
			continue
		_cancel_unit_command(u)
		u["hold"] = true
		n += 1
	if n > 0:
		_effects.feedback("警戒：%d 支部队取消命令、原地待命" % n)
	else:
		_effects.feedback("没有可警戒的部队")
	return n > 0

func _cancel_unit_command(u: Dictionary) -> void:
	u.erase("blocked_cursor")
	u["route_failures"]=0
	_construction.leave(u)
	u["site_follow_uid"] = -1
	preload("res://simulation/movement/action_clock.gd").reset(u)
	u["state"] = "idle"
	u["target"] = null
	UnitPath.set_points(u, [])
	u["pi"] = 0
	u["gather_obj"] = null
	u["repair_target"] = null
	u["build_target"] = null
	u["board_target"] = null
	u["join_target_uid"] = -1
	u["cool"] = 0.0
	u["repath"] = 0.0
	u["blocked_n"] = 0
	u["anim"] = 0.0
	u["hold"] = false
	u.erase("repath_to")
	u["gather_t"] = 0.0
	u["gather_ticks"] = 0
	u["delivery_ticks"] = 0
	u["rest_t"] = 0
	u["build_t"] = 0

func _cmd_rest(actors = null) -> bool:
	var n := 0
	for u in battle.selected if actors == null else actors:
		if u.is_building or not u.alive or u.die_t >= 0.0 or int(u.owner)!=battle.player_owner or bool(u.get("attached",false)):
			continue
		if not _is_hero_unit(u):
			continue
		_cancel_unit_command(u)
		u["state"] = "rest"
		u["rest_t"] = 0
		n += 1
	if n > 0:
		_effects.feedback("休息：%d 支将部队原地休整（每 %d tick +%s 兵力）" % [n, int(Balance.work().restTicks), str(Balance.work().restHp)])
	else:
		_effects.feedback("只有武将部队可以休整")
	return n > 0

func _is_hero_unit(u: Dictionary) -> bool:
	return Roles.is_hero(int(u.get("unit", -1)))

func _construction_workers(commander: Dictionary) -> Array:
	return preload("res://simulation/construction/construction_roster.gd").new(battle.units).construction_workers(commander)

func _selected_construction_workers(actors = null) -> Array:
	var workers := []
	for unit in battle.selected if actors == null else actors:
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
		for i in range(Balance.team_max_members(), members.size()):
			var member: Dictionary = members[i]
			member.group_officer = -1
			if member.state == "build": _cancel_unit_command(member)

func _is_naval(u: Dictionary) -> bool:
	return Roles.is_naval(int(u.get("unit", -1)))

func _nav_layer(u: Dictionary) -> int:
	return 1 if _is_naval(u) and _nav.has_water else 0

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	if battle.selected.is_empty():
		_effects.feedback("先选择部队")
		return
	if battle.cmd_pending == kind:
		_dep_world_orders._clear_pending()
		_effects.feedback("已取消")
		return
	_dep_abilities._reset_jimou()
	battle.duel_pending = false
	battle.cmd_pending = kind
	battle.cmd_pending_data = data
	match kind:
		"move": _effects.feedback("移动：点击目的地")
		"attack": _effects.feedback("攻击：点击敌方单位")
		"transport": _effects.feedback("运输：点击资源点（铁矿／民居／树林／粮堆）")
		"repair": _effects.feedback("修理：点击我方单位或建筑")
		"build": _effects.feedback("建造：点击空地放下工地（%s）" % str(data.get("name", "?")))
		"board": _effects.feedback("上船：点击我方运输船（陆军靠近后自动装载）")
		"join": _effects.feedback("加入：点击我方带将队伍，工人靠近后编入（每队最多15名成员）")
		_: _effects.feedback("选择目标")

func _cmd_disband(actors = null) -> bool:
	var n: int = _dep_officer_teams._order_disband(actors)
	if n <= 0:
		_effects.feedback("请选择武将部队")
	return n > 0

func _commander_for(u: Dictionary) -> Dictionary:
	if not u.get("officer", {}).is_empty(): return u
	var index := int(u.get("group_officer", -1))
	if index < 0: return {}
	for other in battle.units:
		if other.alive and other.die_t < 0 and int(other.owner) == int(u.owner) and int(other.get("officer", {}).get("index", -2)) == index: return other
	return {}

func _command_units(actors = null) -> Array:
	var selected: Array = battle.selected if actors == null else actors
	var result: Array = selected.duplicate()
	var seen := {}
	for unit in result: seen[int(unit.uid)] = true
	for leader in selected:
		if leader.get("officer",{}).is_empty():continue
		for member in battle.units:
			if member.alive and member.die_t<0 and int(member.owner)==int(leader.owner) and int(member.get("group_officer",-1))==int(leader.officer.index) and not seen.has(int(member.uid)):
				result.append(member); seen[int(member.uid)] = true
	return result

func _return_selected_cargo(actors = null) -> bool:
	var count:=0
	for worker in battle.selected if actors == null else actors:
		if not _dep_technology._is_worker_unit(worker) or float(worker.get("carry",0))<=0:continue
		var resource=worker.get("gather_obj")
		_cancel_unit_command(worker)
		worker.gather_obj=resource;worker.state="deliver";count+=1
	_effects.feedback("%d 名工人返回入库" % count)
	return count > 0

func stop_selected(actors = null) -> bool:
	var count := 0
	for u in battle.selected if actors == null else actors:
		if not u.alive or u.is_building:
			continue
		_cancel_unit_command(u)
		count += 1
	if count > 0:
		_effects.feedback("停止")
	return count > 0

## HUD query: one world pass for all ten slots, with value-only records. Empty
## slots and unrelated units do not trigger twenty repeated eligibility scans.
func control_group_summaries() -> Array:
	var result: Array=[];var memberships: Dictionary={}
	for slot in range(1,11):
		result.append({"count":0,"workSiteName":""})
		for raw in battle.control_groups.get(slot,[]):
			var uid:=int(raw)
			if not memberships.has(uid):memberships[uid]={}
			memberships[uid][slot-1]=true
	if not memberships.is_empty():
		for unit: Dictionary in battle.units:
			var uid:=int(unit.uid)
			if not memberships.has(uid) or not unit.alive or unit.die_t>=0 or int(unit.owner)!=battle.player_owner or bool(unit.get("attached",false)):continue
			var site_id:=int(unit.get("site_inside_uid",-1))
			if site_id<0:site_id=int(unit.get("site_follow_uid",-1))
			var site: Dictionary=_construction.site_for(site_id) if site_id>=0 else {}
			var site_name: String=str(site.name) if _construction.active(site) else ""
			for index in memberships[uid]:
				result[index].count+=1
				if result[index].workSiteName=="":result[index].workSiteName=site_name
	for item in result:item.make_read_only()
	result.make_read_only()
	return result

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_officer_teams = world.officer_teams
	_dep_technology = world.technology
	_dep_world_orders = world.world_orders
	_construction = world.construction
	_effects = world.effects
	_nav = world.nav
