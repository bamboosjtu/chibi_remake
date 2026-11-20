extends Object
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
## officer teams: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_abilities: Object
var _dep_battle_simulation: Object
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_entity_factory: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
var _dep_officer_pool: Object
var _dep_production: Object
var _dep_spatial_index: Object
var _dep_technology: Object

func _init(data: State) -> void:
	battle = data

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	if amount < 0.0:
		return
	var commander: Dictionary = _dep_command_groups._commander_for(u)
	var off: Dictionary = commander.get("officer", {})
	if off.is_empty():
		return
	var promoted: bool=preload("res://simulation/officers/officer_progression.gd").award(off,int(amount))
	_dep_officer_pool._sync_officer_to_pool(off)
	if promoted and int(commander.owner)==battle.player_owner:
		_effects.feedback("%s：%s（%d级 · %s）" % [str(off.get("name","")),str(preload("res://simulation/officers/officer_progression.gd").data.levelUp.message),int(off.level),_dep_combat.officer_rank_name(off)])
		if _effects != null:_effects.sound("play_id", [106])
	if _effects != null:_effects.visual("update_panel", [])

func _form_hero_unit(u: Dictionary, idx: int, actors = null) -> bool:
	if _dep_production._army_count(int(u.owner)) >= Balance.army_cap() or _dep_production._commander_count(int(u.owner)) >= Balance.commander_cap(): return false
	if u.is_building or not u.alive or u.die_t >= 0.0 or _dep_officer_pool.officer_in_use(idx): return false
	var o: Dictionary = _dep_officer_pool._officer_by_index(idx)
	if o.is_empty(): return false
	var hero_type := int(o.get("heroType", -1))
	var meta: Dictionary = battle.map_data.units.get(str(hero_type), {})
	if meta.is_empty() or _dep_entity_factory._sheet_ref_for(hero_type, int(u.owner)) == "": return false
	var members: Array = []
	for member in battle.selected if actors == null else actors:
		if member.alive and member.die_t < 0.0 and not member.is_building and member.owner == u.owner and member.get("officer", {}).is_empty() and int(member.get("group_officer", -1)) < 0:
			members.append(member)
			if members.size() == Balance.team_max_members(): break
	if members.is_empty(): return false
	var w := int(meta.get("w", 64))
	var h := int(meta.get("h", 64))
	var want_cell := _nav.near_walkable(_nav.cell_of_px(u.ax, u.ay - battle.tile_hh * 2))
	var cell: Vector2i = _dep_spatial_index._free_unit_cell(want_cell, 0, -1, hero_type)
	if cell.x < 0: return false
	var anchor := _nav.anchor_of(cell.x, cell.y)
	var commander: Dictionary = _dep_entity_factory._make_unit({"unit": hero_type, "owner": int(u.owner), "A": cell.x, "B": cell.y,
		"px": anchor.x - w * 0.5, "py": anchor.y - h, "w": w, "h": h,
		"tail": [], "sheet": _dep_entity_factory._sheet_ref_for(hero_type, int(u.owner))}, false)
	_dep_entity_factory._attach_officer(commander, o)
	commander.team_kind="worker" if members.all(func(member):return _dep_technology._is_worker_unit(member)) else "combat"
	commander.base_maxhp = float(o.get("hp", commander.base_maxhp))
	commander.maxhp = commander.base_maxhp; commander.hp = commander.base_maxhp
	_dep_technology._apply_tech_bonuses(commander)
	battle.units.append(commander)
	if actors == null or battle.selected == actors: battle.selected = [commander]
	for member in members:
		member.group_officer = idx
	_dep_battle_simulation._place_unit(commander)
	return true

func _order_disband(actors = null) -> int:
	var selection_unchanged: bool = actors == null or battle.selected == actors
	var leaders: Array = []
	var detached := 0
	for unit in battle.selected if actors == null else actors:
		if not battle.units.any(func(current): return is_same(current,unit)): continue
		if unit.alive and unit.die_t<0 and int(unit.owner)==battle.player_owner and unit.get("officer",{}).is_empty() and int(unit.get("group_officer",-1))>=0:
			unit.group_officer=-1
			if unit.state=="build":_dep_command_groups._cancel_unit_command(unit)
			detached+=1
		if unit.alive and unit.die_t<0 and not bool(unit.get("attached",false)) and unit.owner == battle.player_owner and not (unit.get("officer", {}) as Dictionary).is_empty():
			leaders.append(unit)
	for leader in leaders:
		var position := battle.units.find_custom(func(current): return int(current.uid)==int(leader.uid) and is_same(current,leader))
		if position < 0: continue
		var idx := int(leader.officer.index)
		for member in battle.units:
			if member.alive and member.owner == leader.owner and int(member.get("group_officer", -1)) == idx:
				member["group_officer"] = -1        # 成员回到"未编组"，可再次组建
		_dep_battle_simulation._clear_control_group_for(int(leader.uid))
		_unassign_officer(leader)
		if battle.jimou_caster == leader:
			_dep_abilities._reset_jimou()
		leader.alive = false
		_dep_battle_simulation._free_unit_at(position)
	if selection_unchanged: battle.selected = []
	if not leaders.is_empty():
		_effects.feedback("部队已解散（%d 队），成员保留，可重新组建" % leaders.size())
	if detached>0:_effects.feedback("%d 名成员已解除编组" % detached)
	return leaders.size()+detached

func _order_join(target: Dictionary, actors = null) -> int:
	var leader: Dictionary = target if not target.get("officer", {}).is_empty() else _dep_command_groups._commander_for(target)
	if leader.is_empty() or not bool(leader.get("alive", false)) or int(leader.owner) != battle.player_owner or leader.is_building:
		_effects.feedback("加入需要点击我方带将队伍")
		return 0
	var idx := int(leader.officer.index)
	var members: Array = battle.units.filter(func(u): return bool(u.alive) and u.die_t < 0 and int(u.owner) == battle.player_owner and int(u.get("group_officer", -1)) == idx)
	var room := Balance.team_max_members() - members.size()
	var count := 0
	for member in (battle.selected if actors == null else actors).duplicate():
		if room <= 0: break
		if not bool(member.alive) or member.is_building or member.die_t >= 0 or int(member.owner) != battle.player_owner or bool(member.get("attached", false)) or not member.get("officer", {}).is_empty() or int(member.get("group_officer", -1)) >= 0: continue
		var path: Array = _dep_interaction_paths._edge_interaction_path(member, leader)
		if path.is_empty(): continue
		_dep_command_groups._cancel_unit_command(member)
		member.state = "join"; member.join_target_uid = int(leader.uid)
		member.path = path; member.pi = 0
		count += 1; room -= 1
	_effects.feedback("已派出%d名成员加入队伍" % count if count > 0 else "队伍已满或无法靠近")
	return count

func _assign_officer_to(u: Dictionary, idx: int) -> bool:
	if u.is_building or not u.alive or u.die_t >= 0.0:
		print("组建：目标不是可指派的部队")
		return false
	if _dep_officer_pool.officer_in_use(idx) and not _dep_officer_pool._officer_held_only_by_selection(idx):
		print("组建：武将 %d 已被占用（原版 CTRL_GROUP_Create_Error）" % idx)
		return false
	# 只被选中部队持有 → 先从原持有者移出（原版 CTRL_GROUP_Sub），再指派
	for u2 in battle.units:
		if u2 == u or not u2.alive:
			continue
		var o2 = u2.get("officer", null)
		if (o2 is Dictionary) and int((o2 as Dictionary).get("index", -1)) == idx:
			_unassign_officer(u2)
	var o: Dictionary = _dep_officer_pool._officer_by_index(idx)
	if o.is_empty():
		print("组建：找不到武将 %d" % idx)
		return false
	if int(u.get("officer", {}).get("index", -1)) >= 0 and int(u.officer.index) != idx:
		_unassign_officer(u)
	_dep_entity_factory._attach_officer(u, o)
	# 原版：单位的 HP 取自**武将 HP**，而武将 HP = 该 tier 对应的"将"类兵种 HP
	# （装载器里文本第 5 个整数读进 HP 后**立即被覆盖**，见 tools/lib/officer_hp.mjs 头部）。
	var ohp := float(o.get("hp", 0))
	if ohp > 0.0:
		u["base_maxhp"] = ohp
		u["maxhp"] = ohp
		u["hp"] = ohp
		_dep_technology._apply_tech_bonuses(u)
	print("组建：%s ← 「%s」%s 武力=%.0f 智力=%.0f HP=%.0f" % [

		str(u.get("name", "?")), str(o.get("name", "?")).replace(" ", ""),
		str(o.get("heroTypeName", "?")),
		float(o.get("might", 0)), float(o.get("intellect", 0)), float(u.get("hp", 0))])
	return true

func _unassign_officer(u: Dictionary) -> void:
	var previous := int(u.get("officer", {}).get("index", -1))
	var previous_off: Dictionary = u.get("officer", {})
	if not previous_off.is_empty():
		_dep_officer_pool._sync_officer_to_pool(previous_off)
	if previous >= 0:
		# Capture the team's identities before unlinking the officer. Death starts
		# here; _finish_death runs later, after the officer field is already empty.
		_dep_battle_simulation._clear_officer_control_groups(previous,int(u.owner),int(u.uid))
		for member in battle.units:
			if member.owner == u.owner and int(member.get("group_officer", -1)) == previous:
				member["group_officer"] = -1
	u["officer"] = {}
	u["officer_might"] = 0.0
	u["officer_intellect"] = 0.0

func _order_form_up(officer_index: int, actors = null) -> bool:
	var done := 0
	for u in (battle.selected if actors == null else actors).duplicate():
		if u.is_building or not u.alive:
			continue
		if _form_hero_unit(u, officer_index, actors):
			done += 1
			break          # 一个武将只带一支部队（占用位唯一）
	if done == 0:
		_effects.visual("feedback", ["组建失败"])
	else:
		_effects.visual("feedback", ["组建完成"])
		_auto_assign_new_team(officer_index)
	return done > 0

func _auto_assign_new_team(officer_index: int) -> void:
	var ids: Array = []
	for u in battle.units:
		if not bool(u.get("alive", false)) or u.die_t >= 0.0 or int(u.owner) != battle.player_owner: continue
		if int(u.get("officer", {}).get("index", -1)) == officer_index or int(u.get("group_officer", -1)) == officer_index:
			ids.append(int(u.uid))
	if ids.is_empty(): return
	for n in range(1, 10):
		var old: Array = battle.control_groups.get(n, [])
		if old.any(func(uid): return int(uid) in ids):
			for uid in ids:
				if not old.has(uid): old.append(uid)
			battle.control_groups[n] = old
			return
	for n in range(1, 10):
		if _dep_command_groups._group_units(n).is_empty():
			battle.control_groups[n] = ids
			return

func _process_officer_recovery() -> void:
	if battle.sim_tick % 100 != 0:
		return
	for u in battle.units:
		if not bool(u.get("alive", false)) or bool(u.is_building):
			continue
		var off: Dictionary = u.get("officer", {})
		if off.is_empty():
			continue
		if float(u.get("inspired_t", 0.0)) > 0.0:
			var cap := 2.0 * float(off.get("intellect", 0.0)) + 15.0
			u["mou"] = minf(cap, float(u.get("mou", 0.0)) + 5.0)
		else:
			u["hp"] = minf(float(u.get("maxhp", 0.0)), float(u.get("hp", 0.0)) + 10.0)

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_battle_simulation = world.battle_simulation
	_dep_combat = world.combat
	_dep_command_groups = world.command_groups
	_dep_entity_factory = world.entity_factory
	_dep_interaction_paths = world.interaction_paths
	_dep_movement = world.movement
	_dep_officer_pool = world.officer_pool
	_dep_production = world.production
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_effects = world.effects
	_nav = world.nav


func step_join(u: Dictionary, delta: float) -> void:
	var leader: Dictionary = {}
	for candidate in battle.units:
		if int(candidate.uid) == int(u.get("join_target_uid", -1)): leader = candidate; break
	if leader.is_empty() or not bool(leader.alive) or leader.die_t >= 0 or leader.get("officer", {}).is_empty() or int(leader.owner) != int(u.owner):
		_dep_command_groups._cancel_unit_command(u)
	elif _dep_interaction_paths._edge_cell_distance(u, leader) <= Config.EDGE_DISTANCE:
		var idx := int(leader.officer.index)
		var members: Array = battle.units.filter(func(member): return bool(member.alive) and member.die_t < 0 and int(member.owner) == int(u.owner) and int(member.get("group_officer", -1)) == idx)
		_dep_command_groups._cancel_unit_command(u)
		if members.size() < Balance.team_max_members():
			u.group_officer = idx
			_auto_assign_new_team(idx)
			_effects.feedback("已加入%s的队伍" % str(leader.officer.name).replace(" ", ""))
		else: _effects.feedback("该队伍已满15名成员")
	else:
		if u.path.is_empty(): u.path = _dep_interaction_paths._edge_interaction_path(u, leader); u.pi = 0
		if u.path.is_empty(): _dep_command_groups._cancel_unit_command(u); _effects.feedback("无法靠近该队伍")
		else: _dep_movement._follow(u, delta)
