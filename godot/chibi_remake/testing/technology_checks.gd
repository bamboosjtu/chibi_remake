extends RefCounted
## Development assertions; shipped for --selftest candidate validation.
var host: Node2D
var _suite: WeakRef
var suite: RefCounted:
	get: return _suite.get_ref()

func _init(battle: Node2D, runner: RefCounted) -> void:
	host = battle
	_suite = weakref(runner) if runner != null else null

func _selftest_tech() -> void:
	print("SELFTEST tech: 表=%d 条 建筑菜单 武器库2=%s 弓兵所14=%s 钱庄23=%s" % [
		host.TECH_TABLE.size(), str(host.commands.tech_rows_for_building(2)),
		str(host.commands.tech_rows_for_building(14)), str(host.commands.tech_rows_for_building(23))])
	suite._check(host.TECH_TABLE.size() == 23, "科技表 23 条（附录 C）")
	var row12: Dictionary = host.TECH_TABLE[12]
	var row22: Dictionary = host.TECH_TABLE[22]
	suite._check(int(row12["v"][0]) == 500 and int(row12["v"][1]) == 1000, "卖木一千 = 金+500 / 木−1000")
	suite._check(int(row22["v"][4]) == 6 and int(row22["v"][5]) == 10, "装甲升级效果列 = 6/10（B8D23/B8D24）")
	suite._check(host.commands.tech_rows_for_building(2).has(6), "武器库菜单含「兵器一级」")
	suite._check(host.commands.tech_rows_for_building(4).has(3) and not host.commands.tech_rows_for_building(14).has(3), "弓术研究位于木材场")
	suite._check(host.commands.tech_rows_for_building(23).size() == 6, "钱庄菜单含 6 条卖资源")
	suite._check(host.commands.tech_rows_for_building(8).has(18), "车兵所菜单含「投石车一级」")
	suite._check(host.commands.tech_rows_for_building(20).has(20), "船坞菜单含「快船升级」")
	# UI 烟雾：真实走一遍 battle_view 的建筑分支（研究条目与生产条目同页）。
	if host.view != null:
		var ub: Dictionary = {}
		for u in host.units:
			if bool(u.get("alive", false)) and int(u.unit) in [0,1] and int(u.get("owner", -1)) == host.player_owner:
				ub = u
				break
		if not ub.is_empty():
			host.selected = [ub]
			host.view._refresh_cmd_panel()
			print("SELFTEST tech: UI 建筑 unit=%d 条目=%d" % [int(ub.unit), host.view.cmd_capsules.size()])
			suite._check(host.view.cmd_capsules.size() > 0, "选中建筑后命令面板渲染研究/生产条目")
			host.selected.clear()
	# 自检只在 _ready 跑一次；先归零，保证从"未研发"状态验证完整流程。
	host.player_tech = {"level": 0, "bow": 0, "weapon": 0, "armor": 0, "catapult": 0, "ship_atk": 0, "ship_def": 0}
	host.tech_progress = {}
	# 本图（CHIBIC1）我方可能只有工兵；找一个近战单位，没有就临时生成步兵 32 用于断言。
	var melee: Dictionary = {}
	for u in host.units:
		if bool(u.get("alive", false)) and not bool(u.is_building) and int(u.get("owner", -1)) == host.player_owner \
				and host.commands._is_melee_unit(u) and not host.CombatRules.hero(u) and host.commands._combat_tech_category(int(u.unit)) >= 0:
			melee = u
			break
	if melee.is_empty():
		var b: Dictionary = {}
		for u in host.units:
			if bool(u.get("alive", false)) and bool(u.is_building) and int(u.get("owner", -1)) == host.player_owner:
				b = u
				break
		if not b.is_empty():
			for off in [Vector2(96, 96), Vector2(-96, 96), Vector2(96, -96), Vector2(-96, -96)]:
				if host.commands._spawn_unit(32, host.player_owner, float(b.ax) + off.x, float(b.ay) + off.y):
					melee = host.units.back()
					break
	if melee.is_empty():
		suite._skip("科技自检：本图无法生成近战单位")
		return
	print("SELFTEST tech: 近战样本 unit=%d uid=%d attack_bonus=%.0f" % [
		int(melee.unit), int(melee.uid), float(melee.get("attack_bonus", 0.0))])
	host.gold += 10000.0
	host.wood += 10000.0
	host.food += 10000.0
	host.stone += 10000.0
	var anchor = Vector2(float(melee.ax), float(melee.ay))
	# --- 卖资源行（12–17）：必须选中钱庄；本图没有就临时放一座测试钱庄 ---
	var bank = suite.technology._selftest_ensure_building([23], anchor)
	if bank.is_empty():
		suite._skip("科技自检：本图无法放置钱庄，跳过卖资源断言")
	else:
		host.selected = [bank]
		var sg = host.gold
		var sw = host.wood
		var sold = host.commands._start_tech(12)
		suite._check(sold, "卖木一千下单")
		suite._check(host.commands.tech_research_active(), "卖资源进入 200 tick 队列")
		for i in range(host.TECH_TICKS):
			host.commands._process_tech(1.0 / 30.0)
		suite._check(not host.commands.tech_research_active(), "卖资源 200 tick 后成交")
		suite._check(is_equal_approx(host.gold, sg + 500.0) and is_equal_approx(host.wood, sw - 1000.0),
			"卖木一千：金+500 / 木−1000（200 tick）")
	# --- 开始研究：必须选中武器库；立即扣费 + 同时只能一项 ---
	var weapon_b = suite.technology._selftest_ensure_building([2, 3], anchor)
	if weapon_b.is_empty():
		suite._skip("科技自检：本图无法放置武器库，跳过兵器研究断言")
		return
	host.selected = [weapon_b]
	var g0 = host.gold
	var w0 = host.wood
	var s0 = host.stone
	var began = host.commands._start_tech(6)
	suite._check(began, "科技 6「兵器一级」开始研究")
	suite._check(host.commands.tech_research_active(), "研究已进入 200 tick 队列")
	print("SELFTEST tech: 扣费 金 %.0f→%.0f 木 %.0f→%.0f 石 %.0f→%.0f（期望 −800/0/−100）" % [
		g0, host.gold, w0, host.wood, s0, host.stone])
	suite._check(is_equal_approx(host.gold, g0 - 800.0), "开始研究立即扣金 800")
	suite._check(is_equal_approx(host.wood, w0), "兵器一级不扣木材")
	suite._check(is_equal_approx(host.stone, s0 - 100.0), "开始研究立即扣铁 100")
	var g1 = host.gold
	var second = host.commands._start_tech(7)
	suite._check(not second, "研究进行中时第二次开始被拒绝")
	suite._check(is_equal_approx(host.gold, g1), "被拒绝的第二次开始没有扣费")
	# --- 200 tick 后生效：直接走队列处理器，避免 AI 在 6.7 秒里改变样本状态 ---
	for i in range(host.TECH_TICKS):
		host.commands._process_tech(1.0 / 30.0)
	suite._check(not host.commands.tech_research_active(), "200 tick 后研究队列清空")
	print("SELFTEST tech: 完成后 attack_bonus=%.0f（期望表值 %.0f） player_tech=%s" % [
		float(melee.get("attack_bonus", 0.0)),
		host.commands._combat_tech_value("weapon", 6, host.commands._combat_tech_category(int(melee.unit)), host.player_owner), str(host.player_tech)])
	suite._check(int(host.player_tech.get("weapon", 0)) == 1, "兵器等级 = 1")
	suite._check(is_equal_approx(float(melee.get("attack_bonus", 0.0)),
		host.commands._combat_tech_value("weapon", 6, host.commands._combat_tech_category(int(melee.unit)), host.player_owner)),
		"兵器一级 → 本兵种档位 attack_bonus = 表值")
	# --- 取消返还 75%（以"扣费后余额"为基准）---
	var began2 = host.commands._start_tech(7)
	suite._check(began2, "科技 7「兵器二级」开始研究")
	var g2 = host.gold
	var w2 = host.wood
	var s2 = host.stone
	var cancelled = host.commands._cancel_tech()
	suite._check(cancelled, "取消研究")
	print("SELFTEST tech: 取消返还 金 %.0f→%.0f 木 %.0f→%.0f 石 %.0f→%.0f（期望 +1500/+450/+225）" % [
		g2, host.gold, w2, host.wood, s2, host.stone])
	suite._check(not host.commands.tech_research_active(), "取消后研究队列清空")
	suite._check(is_equal_approx(host.gold, g2 + 1500.0), "取消返还 75% 金（2000→1500）")
	suite._check(is_equal_approx(host.wood, w2 + 450.0), "取消返还 75% 木（600→450）")
	suite._check(is_equal_approx(host.stone, s2 + 225.0), "取消返还 75% 铁（300→225）")

## 水战/装载（模式 0xC/0xD）正向验证：
##   · 水军按水面层寻路（水面格可走、陆地格不可走）；
##   · 陆军靠近运输船 → 附着（carry_n/loaded）→ 下船在船附近最近可走陆地复位。
## 只在有 `waterWalkable` 的图上跑（纯陆战图打印跳过）。

func _selftest_ensure_building(unit_ids: Array, near: Vector2) -> Dictionary:
	for u in host.units:
		if bool(u.get("alive", false)) and float(u.get("die_t", -1.0)) < 0.0 \
				and bool(u.get("is_building", false)) and not bool(u.get("site", false)) \
				and int(u.get("owner", -1)) == host.player_owner and unit_ids.has(int(u.get("unit", -1))):
			return u
	var anchors: Array = [near]
	for u in host.units:
		if bool(u.get("alive", false)) and bool(u.get("is_building", false)) \
				and int(u.get("owner", -1)) == host.player_owner:
			anchors.append(Vector2(float(u.ax), float(u.ay)))
	anchors.append(Vector2(float(host.map_data.terrainW) * 0.5, float(host.map_data.terrainH) * 0.5))
	for anchor in anchors:
		for id in unit_ids:
			var b = host.commands._place_building(host.player_owner, int(id), anchor)
			if not b.is_empty():
				return b
	return {}

func _selftest_build() -> void:
	if host.build_types.is_empty():
		print("SELFTEST build: 本关 build_types 为空 —— 跳过")
		return
	# 原版建造由**武将带领的工人队**发起（16139 → 模式 8）；独立工人不能发起施工。
	var builder: Dictionary = {}
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner and host.commands._construction_workers(u).size() > 0:
			builder = u
			break
	if builder.is_empty():
		suite._skip("建造：本图没有可施工的武将工人队")
		return
	host.selected.clear()
	host.selected.append(builder)
	var crew: Array = host.commands._construction_workers(builder)
	var before = host.units.size()
	host.gold += 10000.0
	host.wood += 10000.0
	host.food += 10000.0
	host.stone += 10000.0
	var opt: Dictionary = host.build_types[0]
	host.commands._start_build(opt)
	print("SELFTEST build: 选中武将工人队 → _start_build → pending=%s (应 build)" % host.commands.cmd_pending_kind())
	suite._check(host.commands.cmd_pending_kind() == "build", "建造：选中工人队后进入“点地点”状态（模式 8）")
	# 走真实的"点地图"路径（_order_at → _resolve_pending → _build_site_at）
	var point = Vector2(float(builder.ax) + 96.0, float(builder.ay) + 32.0)
	var origin = host.commands._unit_cell(builder)
	var found = false
	for r in range(2, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var candidate = host.nav.anchor_of(origin.x + dx, origin.y + dy)
				if host.commands.build_placement_at(candidate, opt).valid:
					point = candidate; found = true; break
			if found: break
		if found: break
	host.commands._order_at(point)
	var site: Dictionary = host.units.back() if host.units.size() > before else {}
	print("SELFTEST build: 建造「%s」 units %d -> %d (应 +1)  site=%s HP=%.0f/%.0f  建筑=%d" % [
		str(opt.get("name", "?")), before, host.units.size(), str(bool(site.get("site", false))),
		float(site.get("hp", -1.0)), float(site.get("maxhp", 0.0)),
		host.commands._force_counts(host.player_owner).buildings])
	suite._check(host.units.size() == before + 1, "玩家建造：点空地后落工地（单位数 +1）")
	suite._check(not site.is_empty() and bool(site.get("site", false)) and float(site.get("hp", -1.0)) == 0.0,
		"工地 HP=0 起步（模式 0x13，建造进度未满不算建成）")
	# 工人到位后按 **4 tick +2 HP** 推进；20 秒（600 tick）应明显上涨。
	var hp0 = float(site.get("hp", 0.0))
	for i in range(600):
		for w in crew:
			host.commands._step_unit(w, 1.0 / 30.0)
	print("SELFTEST build: 工地推进 %.0f → %.0f（20 秒，%d 名工人；理论 15 HP/秒 − 走路时间）" % [
		hp0, float(site.get("hp", 0.0)), crew.size()])
	suite._check(float(site.get("hp", 0.0)) > hp0, "工人按 4 tick +2 HP 推进工地")
	host.selected.clear()
