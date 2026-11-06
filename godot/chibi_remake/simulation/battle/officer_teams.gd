extends RefCounted
## officer teams: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/officer_teams_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	if amount < 0.0:
		return
	var commander := ports._commander_for(u)
	var off: Dictionary = commander.get("officer", {})
	if off.is_empty():
		return
	var promoted: bool=preload("res://simulation/systems/officer_progression.gd").award(off,int(amount))
	ports._sync_officer_to_pool(off)
	if promoted and int(commander.owner)==battle.player_owner:
		ports._feedback("%s：%s（%d级 · %s）" % [str(off.get("name","")),str(preload("res://simulation/systems/officer_progression.gd").data.levelUp.message),int(off.level),ports.officer_rank_name(off)])
		if battle.effects != null:battle.effects.sound("play_id", [106])
	if battle.effects != null:battle.effects.visual("update_panel", [])

func _form_hero_unit(u: Dictionary, idx: int) -> bool:
	if ports._army_count(int(u.owner)) >= 200 or ports._commander_count(int(u.owner)) >= 20: return false
	if u.is_building or not u.alive or u.die_t >= 0.0 or ports.officer_in_use(idx): return false
	var o := ports._officer_by_index(idx)
	if o.is_empty(): return false
	var hero_type := int(o.get("heroType", -1))
	var meta: Dictionary = battle.map_data.units.get(str(hero_type), {})
	if meta.is_empty() or ports._sheet_ref_for(hero_type, int(u.owner)) == "": return false
	var members: Array = []
	for member in battle.selected:
		if member.alive and member.die_t < 0.0 and not member.is_building and member.owner == u.owner and member.get("officer", {}).is_empty() and int(member.get("group_officer", -1)) < 0:
			members.append(member)
			if members.size() == Config.TEAM_MAX_MEMBERS: break
	if members.is_empty(): return false
	var w := int(meta.get("w", 64))
	var h := int(meta.get("h", 64))
	var want_cell := battle.nav.near_walkable(battle.nav.cell_of_px(u.ax, u.ay - battle.tile_hh * 2))
	var cell := ports._free_unit_cell(want_cell, 0, -1, hero_type)
	if cell.x < 0: return false
	var anchor := battle.nav.anchor_of(cell.x, cell.y)
	var commander := ports._make_unit({"unit": hero_type, "owner": int(u.owner), "A": cell.x, "B": cell.y,
		"px": anchor.x - w * 0.5, "py": anchor.y - h, "w": w, "h": h,
		"tail": [], "sheet": ports._sheet_ref_for(hero_type, int(u.owner))}, false)
	ports._attach_officer(commander, o)
	commander.team_kind="worker" if members.all(func(member):return ports._is_worker_unit(member)) else "combat"
	commander.base_maxhp = float(o.get("hp", commander.base_maxhp))
	commander.maxhp = commander.base_maxhp; commander.hp = commander.base_maxhp
	ports._apply_tech_bonuses(commander)
	battle.units.append(commander)
	battle.selected = [commander]
	for member in members:
		member.group_officer = idx
	ports._place_unit(commander)
	return true

func _order_disband() -> int:
	var leaders: Array = []
	var detached := 0
	for unit in battle.selected:
		if unit.alive and unit.die_t<0 and int(unit.owner)==battle.player_owner and unit.get("officer",{}).is_empty() and int(unit.get("group_officer",-1))>=0:
			unit.group_officer=-1
			if unit.state=="build":ports._cancel_unit_command(unit)
			detached+=1
		if unit.alive and unit.die_t<0 and not bool(unit.get("attached",false)) and unit.owner == battle.player_owner and not (unit.get("officer", {}) as Dictionary).is_empty():
			leaders.append(unit)
	for leader in leaders:
		var idx := int(leader.officer.index)
		for member in battle.units:
			if member.alive and member.owner == leader.owner and int(member.get("group_officer", -1)) == idx:
				member["group_officer"] = -1        # 成员回到"未编组"，可再次组建
		ports._clear_control_group_for(int(leader.uid))
		_unassign_officer(leader)
		if battle.jimou_caster == leader:
			ports._reset_jimou()
		leader.alive = false
		ports._free_unit_at(battle.units.find(leader))
	battle.selected = []                                   # 原版：解散即清空选择
	if not leaders.is_empty():
		ports._feedback("部队已解散（%d 队），成员保留，可重新组建" % leaders.size())
	if detached>0:ports._feedback("%d 名成员已解除编组" % detached)
	return leaders.size()+detached

func _order_join(target: Dictionary) -> int:
	var leader: Dictionary = target if not target.get("officer", {}).is_empty() else ports._commander_for(target)
	if leader.is_empty() or not bool(leader.get("alive", false)) or int(leader.owner) != battle.player_owner or leader.is_building:
		ports._feedback("加入需要点击我方带将队伍")
		return 0
	var idx := int(leader.officer.index)
	var members: Array = battle.units.filter(func(u): return bool(u.alive) and u.die_t < 0 and int(u.owner) == battle.player_owner and int(u.get("group_officer", -1)) == idx)
	var room := Config.TEAM_MAX_MEMBERS - members.size()
	var count := 0
	for member in battle.selected.duplicate():
		if room <= 0: break
		if not bool(member.alive) or member.is_building or member.die_t >= 0 or int(member.owner) != battle.player_owner or bool(member.get("attached", false)) or not member.get("officer", {}).is_empty() or int(member.get("group_officer", -1)) >= 0: continue
		var path := ports._edge_interaction_path(member, leader)
		if path.is_empty(): continue
		ports._cancel_unit_command(member)
		member.state = "join"; member.join_target_uid = int(leader.uid)
		member.path = path; member.pi = 0
		count += 1; room -= 1
	ports._feedback("已派出%d名成员加入队伍" % count if count > 0 else "队伍已满或无法靠近")
	return count

func _assign_officer_to(u: Dictionary, idx: int) -> bool:
	if u.is_building or not u.alive or u.die_t >= 0.0:
		print("组建：目标不是可指派的部队")
		return false
	if ports.officer_in_use(idx) and not ports._officer_held_only_by_selection(idx):
		print("组建：武将 %d 已被占用（原版 CTRL_GROUP_Create_Error）" % idx)
		return false
	# 只被选中部队持有 → 先从原持有者移出（原版 CTRL_GROUP_Sub），再指派
	for u2 in battle.units:
		if u2 == u or not u2.alive:
			continue
		var o2 = u2.get("officer", null)
		if (o2 is Dictionary) and int((o2 as Dictionary).get("index", -1)) == idx:
			_unassign_officer(u2)
	var o := ports._officer_by_index(idx)
	if o.is_empty():
		print("组建：找不到武将 %d" % idx)
		return false
	if int(u.get("officer", {}).get("index", -1)) >= 0 and int(u.officer.index) != idx:
		_unassign_officer(u)
	ports._attach_officer(u, o)
	# 原版：单位的 HP 取自**武将 HP**，而武将 HP = 该 tier 对应的"将"类兵种 HP
	# （装载器里文本第 5 个整数读进 HP 后**立即被覆盖**，见 tools/lib/officer_hp.mjs 头部）。
	var ohp := float(o.get("hp", 0))
	if ohp > 0.0:
		u["base_maxhp"] = ohp
		u["maxhp"] = ohp
		u["hp"] = ohp
		ports._apply_tech_bonuses(u)
	print("组建：%s ← 「%s」%s 武力=%.0f 智力=%.0f HP=%.0f" % [

		str(u.get("name", "?")), str(o.get("name", "?")).replace(" ", ""),
		str(o.get("heroTypeName", "?")),
		float(o.get("might", 0)), float(o.get("intellect", 0)), float(u.get("hp", 0))])
	return true

func _unassign_officer(u: Dictionary) -> void:
	var previous := int(u.get("officer", {}).get("index", -1))
	var previous_off: Dictionary = u.get("officer", {})
	if not previous_off.is_empty():
		ports._sync_officer_to_pool(previous_off)
	if previous >= 0:
		# Capture the team's identities before unlinking the officer. Death starts
		# here; _finish_death runs later, after the officer field is already empty.
		ports._clear_officer_control_groups(previous,int(u.owner),int(u.uid))
		for member in battle.units:
			if member.owner == u.owner and int(member.get("group_officer", -1)) == previous:
				member["group_officer"] = -1
	u["officer"] = {}
	u["officer_might"] = 0.0
	u["officer_intellect"] = 0.0

func _order_form_up(officer_index: int) -> void:
	var done := 0
	for u in battle.selected.duplicate():
		if u.is_building or not u.alive:
			continue
		if _form_hero_unit(u, officer_index):
			done += 1
			break          # 一个武将只带一支部队（占用位唯一）
	if done == 0:
		battle.feedback_text = "组建失败"
	else:
		battle.feedback_text = "组建完成"
		_auto_assign_new_team(officer_index)

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
		if ports._group_units(n).is_empty():
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
