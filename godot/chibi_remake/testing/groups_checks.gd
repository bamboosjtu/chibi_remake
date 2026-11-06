extends RefCounted
## Development assertions; shipped for --selftest candidate validation.
var host: Node2D
var _suite: WeakRef
var suite: RefCounted:
	get: return _suite.get_ref()

func _init(battle: Node2D, runner: RefCounted) -> void:
	host = battle
	_suite = weakref(runner) if runner != null else null

func _selftest_ctrlgroup() -> void:
	var tgt: Dictionary = {}
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner:
			if not (u.get("officer", {}) as Dictionary).is_empty():
				tgt = u
				break
	if tgt.is_empty():
		suite._skip("组建：我方没有带将的部队")
		return
	var uid0: int = int(tgt.uid)
	var type_before: int = int(tgt.unit)
	var freed: int = int((tgt.get("officer", {}) as Dictionary).get("index", -1))
	host.commands.military._unassign_officer(tgt)
	var avail = host.commands.military.available_officers(host.player_owner)
	print("SELFTEST 组建: 解除武将 %d 后可组建 %d 人" % [freed, avail.size()])
	if avail.is_empty():
		suite._skip("组建：仍无可用武将")
		return
	var opt: Dictionary = avail[0]
	var idx: int = int(opt.get("index", -1))
	var hero_type: int = int(opt.get("heroType", -1))
	var before = avail.size()
	host.selected.clear()
	host.selected.append(tgt)
	host.commands.military._order_form_up(idx)
	# 组建模型（原版 CTRL_GROUP_Create）= **新将本体单位 + 原部队成为其下属成员**：
	#   将本体 `+0x150` 指向武将，成员 `+0x152`/`group_officer` 指向将；不是把原单位改成将兵种。
	var commander: Dictionary = {}
	for u in host.units:
		if int((u.get("officer", {}) as Dictionary).get("index", -1)) == idx:
			commander = u
			break
	var member: Dictionary = {}
	for u in host.units:
		if int(u.uid) == uid0:
			member = u
			break
	var after = host.commands.military.available_officers(host.player_owner).size()
	print("SELFTEST 组建: 兵种%d 的部队 + 「%s」%s(id%d) → 将本体 uid=%s HP=%.0f；成员 uid=%d group=%d  可用 %d -> %d" % [
		type_before, str(opt.get("name", "?")).replace(" ", ""), str(opt.get("heroTypeName", "?")), hero_type,
		str(int(commander.get("uid", -1))), float(commander.get("hp", 0)),
		uid0, int(member.get("group_officer", -1)), before, after])
	suite._check(not commander.is_empty(), "组建后生成将本体单位（原版 CTRL_GROUP_Create）")
	suite._check(int(commander.get("unit", -1)) == hero_type, "将本体兵种 = 武将 heroType（文/步/弓/骑将）")
	suite._check(is_equal_approx(float(commander.get("hp", 0)), float(opt.get("hp", 0))), "将本体 HP 取自武将 HP")
	suite._check(not member.is_empty() and int(member.get("group_officer", -1)) == idx, "原部队成为该将的下属成员（group_officer）")
	suite._check(after == before - 1, "组建后可用武将 -1（占用唯一）")
	suite._check(host.commands.military.officer_in_use(idx), "组建后该武将被标记占用")
	# 独占：指派给**不在选中集里的**另一支部队 → 应被拒绝
	var other: Dictionary = {}
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner and int(u.uid) != int(commander.get("uid", -1)):
			if (u.get("officer", {}) as Dictionary).is_empty():
				other = u
				break
	host.selected.clear()
	if other.is_empty():
		suite._skip("组建：没有第二支部队可测独占")
	else:
		var r = host.commands.military._assign_officer_to(other, idx)
		print("SELFTEST 组建: 指派给别的部队=%s (应 false，独占)" % str(r))
		suite._check(r == false, "独占：不能指派给别的部队")
	# 移出再指派（选中持有者自己）应当允许
	host.selected.append(commander)
	var r2 = host.commands.military._assign_officer_to(commander, idx)
	print("SELFTEST 组建: 移出再指派给同一支=%s (应 true)" % str(r2))
	suite._check(r2, "选中持有者自己时可以移出再指派")
	host.selected.clear()
	host.commands.military._kill(commander)
	print("SELFTEST 组建: 将本体阵亡后占用=%s (应 false)  成员 group=%d (应 -1)" % [
		str(host.commands.military.officer_in_use(idx)), int(member.get("group_officer", -2))])
	suite._check(not host.commands.military.officer_in_use(idx), "阵亡释放武将（FUN_00443020）")
	suite._check(int(member.get("group_officer", -2)) == -1, "将阵亡后成员解绑（可再次组建）")
	# 用户实测场景：选中若干部队后，候选里必须能看到他们自己持有的武将
	host.selected.clear()
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner:
			host.selected.append(u)
	var cand: Array = host.commands.military.officers_for_selection(host.player_owner, host.selected)
	print("SELFTEST 组建: 选中 %d 支部队 → 候选 %d 人（未被占用的 + 他们自己持有的）" % [
		host.selected.size(), cand.size()])
	suite._check(cand.size() > 0, "选中部队后组建候选非空（用户实测场景）")
	host.selected.clear()

func _selftest_group() -> void:
	var mob: Array = []
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner:
			mob.append(u)
			if mob.size() >= 3:
				break
	if mob.size() < 2:
		print("SELFTEST group: 我方机动单位不足 2 个 —— 跳过")
		return
	host.selected.clear()
	for u in mob:
		host.selected.append(u)
	host.commands.military._group_assign(3)
	host.selected.clear()
	var ok = host.commands.military._group_recall(3)
	print("SELFTEST group: 编入 %d 个 → 呼出=%s 选中 %d 个 (应 %d)  组大小=%d" % [
		mob.size(), str(ok), host.selected.size(), mob.size(), host.commands.military.control_group_size(3)])
	suite._check(ok, "编队呼出成功")
	suite._check(host.selected.size() == mob.size(), "呼出编队后选中数一致")
	host.selected.clear()
	# 空组不能吞按键 —— 否则 1/2 的生产热键会失效
	print("SELFTEST group: 空组呼出=%s (应 false，代表按键会落回原行为)" % str(host.commands.military._group_recall(7)))
	suite._check(host.commands.military._group_recall(7) == false, "空组不吞按键（1/2 生产热键仍可用）")

	# 警戒（原版 16132 → **模式 3**）：**取消当前命令 + 原地待命**，不是开关。
	var h: Dictionary = mob[0]
	var near = host.commands.military._nearest_enemy(h, float(h.vision) * host.tile_w)
	h["state"] = "move"
	h["path"] = [Vector2(float(h.ax) + 240.0, float(h.ay))]
	h["pi"] = 0
	h["hold"] = false
	host.selected.clear()
	host.selected.append(h)
	host.commands.military._cmd_watch()
	print("SELFTEST 警戒: 视野内有敌=%s  下达后 state=%s hold=%s path=%d (应 idle/true/0)" % [
		str(not near.is_empty()), str(h.get("state", "?")), str(bool(h.get("hold", false))), h.get("path", []).size()])
	suite._check(str(h.get("state", "")) == "idle" and h.get("path", []).is_empty(), "警戒取消当前命令（移动命令被撤销）")
	suite._check(bool(h.get("hold", false)), "警戒后原地待命、不再自动索敌")
	host.commands.military._cmd_watch()
	suite._check(bool(h.get("hold", false)), "警戒不是开关：再次下令仍是待命")
	host.selected.clear()
