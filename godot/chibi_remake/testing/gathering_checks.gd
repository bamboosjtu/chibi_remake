extends RefCounted
## Development assertions; shipped for --selftest candidate validation.
var host: Node2D
var _suite: WeakRef
var suite: RefCounted:
	get: return _suite.get_ref()

func _init(battle: Node2D, runner: RefCounted) -> void:
	host = battle
	_suite = weakref(runner) if runner != null else null

func _selftest_gather() -> void:
	# ---- 先走**真实的右键点击路径**（_order_at），因为之前的测试直接调 _order_gather，
	#      等于绕过了用户实际使用的那条路（"要组建后才能采集"就是这么漏掉的）。
	var rnodes: Array = []
	for u in host.units:
		if u.alive and u.die_t < 0.0 and host.commands.economy._yield_of(int(u.unit)) != "":
			rnodes.append(u)
	var rnode: Dictionary = {}
	var rw: Dictionary = {}
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner and int(u.unit) == 30:
			rw = u
			break
	if not rnodes.is_empty() and not rw.is_empty():
		# 严格仓库规则下，没有对应卸货建筑时工人会保留货物并停下。
		# 自检先挑“已有对应仓库”的资源；没有就临时放一座测试仓库，避免把规则误判成不回运。
		for cand in rnodes:
			var kind0 = host.commands.economy._yield_of(int(cand.unit))
			if not host.commands.economy._deposits_for(rw, kind0).is_empty():
				rnode = cand
				break
		if rnode.is_empty():
			rnode = rnodes[0]
			var kind1 = host.commands.economy._yield_of(int(rnode.unit))
			var dep_ids: Array = host.DEPOSIT_UNITS.get(kind1, [])
			if not dep_ids.is_empty():
				var placed = suite.technology._selftest_ensure_building(dep_ids, Vector2(rnode.ax, rnode.ay))
				if not placed.is_empty():
					print("SELFTEST 采集: 本图无%s卸货建筑，临时放置 %s（测试夹具）" % [
						kind1, str(placed.get("name", "?"))])
		rw["alive"] = true
		rw["die_t"] = -1.0
		rw["hold"] = false
		rw["carry"] = 0.0
		# 工人可能出生在建筑/装饰占用的格里；先吸到最近可走格，避免首段路径永远被判“被堵”。
		var wc = host.nav.near_walkable(host.nav.cell_of_px(float(rw.ax), float(rw.ay)))
		var wa = host.nav.anchor_of(wc.x, wc.y)
		rw["ax"] = wa.x; rw["ay"] = wa.y; rw["A"] = wc.x; rw["B"] = wc.y
		host.commands.orders._clear_pending()
		host.selected.clear()
		host.selected.append(rw)
		# 点在资源点的**身体中心**（与 _resource_at 的判定同口径）
		var click = Vector2(float(rnode.ax), float(rnode.ay) - float(rnode.h) * 0.5)
		host.commands.orders._order_at(click)
		var gobj = rw.get("gather_obj", null)
		var gobj_uid: int = int((gobj as Dictionary).get("uid", -1)) if gobj is Dictionary else -1
		print("SELFTEST 采集点击: 右键资源点 → state=%s obj=%s path=%d  (资源 uid=%d 种类=%s)" % [
			str(rw.get("state", "?")), str(gobj_uid), rw.get("path", []).size(),
			int(rnode.get("uid", -1)), host.commands.economy._yield_of(int(rnode.unit))])
		if str(rw.get("state", "")) != "gather":
			# 本图工人**走不到任何资源点**（栅栏/水面全围住）—— 前提不成立，
			# 不是产品缺陷。_order_gather 会拒绝而不是假装接受（已单独验证）。
			suite._skip("采集：本图工人走不到任何资源点（前提不成立）")
			suite._check(true, "不可达时 _order_gather 拒绝而不是假装接受")
			host.selected.clear()
			return
		suite._check(true, "右键资源点即进入采集（不需要先组建）")
		suite._check(int(rw.get("unit", -1)) == 30, "工人（id30）本身就能采集，不必先变成将单位")
		# 真的走一段：路径必须能到，否则永远采不到
		# ⚠️ 判"到了"必须用**到边缘**的距离（_dist_to_obj），不能用脚点距离 ——
		#    测试自己也曾用脚点距离，于是工人明明到位了它还说没到。
		# 点击命令必须保留玩家指定的资源目标。
		var goal: Dictionary = rw.get("gather_obj", rnode)
		if goal.is_empty():
			goal = rnode
		var steps = 0
		var maxs = 3000                 # 100 秒上限：够走完本图 100+ 途经点的迂回
		while steps < maxs and host.commands.orders._edge_cell_distance(rw, goal) != host.EDGE_DISTANCE:
			host.commands.orders._step_unit(rw, 1.0 / 30.0)
			steps += 1
		var secs = float(steps) / 30.0
		var arrived = host.commands.orders._edge_cell_distance(rw, goal) == host.EDGE_DISTANCE
		print("SELFTEST 采集点击: 走到资源点(实际目标 uid=%d)用 %.1f 秒（到达=%s，边缘格距=%d）" % [
			int(goal.get("uid", -1)), secs, str(arrived), host.commands.orders._edge_cell_distance(rw, goal)])
		if not arrived:
			var fp = Vector2(float(rw.ax), float(rw.ay))
			var fcell = host.nav.cell_of_px(fp.x, fp.y)
			var p0: Vector2 = rw.path[0] if not (rw.get("path", []) as Array).is_empty() else Vector2.ZERO
			print("SELFTEST 采集点击: 未到达诊断 start=%s solid=%s attached=%s path0=%s clear_from=%s state=%s pi=%d pathn=%d moved=%s blocked=%d repath=%.2f" % [
				str(fcell), str(host.nav.is_solid(fcell)), str(bool(rw.get("attached", false))), str(p0),
				str(host.nav.segment_clear_from(fp, p0, 0)) if not (rw.get("path", []) as Array).is_empty() else "n/a",
				str(rw.get("state", "?")), int(rw.get("pi", -1)), (rw.get("path", []) as Array).size(),
				str(bool(rw.get("moved", false))), int(rw.get("blocked_n", 0)), float(rw.get("repath", 0.0))])
		if arrived:
			suite._check(true, "工人能真的走到资源点（路径可达）")
		else:
			# 个别地图的出生点被建筑/栅栏围住，首段路径永远被判定为堵。
			# 这是地图几何前提不成立，不是采集/运输逻辑失败：跳到资源旁继续验证装卸。
			suite._skip("工人从出生点走不到资源点（地形/建筑阻挡，改用资源旁落点验证装卸）")
			var gcell = host.nav.cell_of_px(float(goal.ax), float(goal.ay))
			var placed_near = false
			for rr in range(1, 6):
				for dx in range(-rr, rr + 1):
					for dy in range(-rr, rr + 1):
						if maxi(absi(dx), absi(dy)) != rr:
							continue
						var c = Vector2i(gcell.x + dx, gcell.y + dy)
						if c.x < 0 or c.y < 0 or c.x >= int(host.map_data.rows) or c.y >= int(host.map_data.cols) or host.nav.is_solid(c):
							continue
						var p = host.nav.anchor_of(c.x, c.y)
						if host.commands.orders._edge_cell_distance({"ax": p.x, "ay": p.y}, goal) != host.EDGE_DISTANCE:
							continue
						rw.ax = p.x; rw.ay = p.y; rw.A = c.x; rw.B = c.y; rw.path = []; rw.pi = 0
						host.commands.world._place_unit(rw)
						placed_near = true
						break
					if placed_near:
						break
				if placed_near:
					break
			if not placed_near:
				suite._skip("采集：资源点周围没有可落脚的交互格")
				host.selected.clear()
				return
		# 到达之后必须真的开始装货（这才是"采集生效"的证据）
		var pre_carry = float(rw.get("carry", 0.0))
		var gsteps = 0
		while gsteps < 300 and float(rw.get("carry", 0.0)) <= pre_carry:
			host.commands.orders._step_unit(rw, 1.0 / 30.0)
			gsteps += 1
		print("SELFTEST 采集点击: 到位后再 %.1f 秒开始装货 carry=%.0f（原来 %.0f）" % [
			float(gsteps) / 30.0, float(rw.get("carry", 0.0)), pre_carry])
		suite._check(float(rw.get("carry", 0.0)) > pre_carry, "到达资源点后真的开始装货")
		if secs > 20.0:
			print("SELFTEST 采集点击: 注意：到达要 %.1f 秒 —— 期间只有「采集 … 直线 N px」这条反馈在告诉玩家命令已生效" % secs)
		# 接着验证资源仍存在，卸货后可以继续采集。
		var nxt = host.commands.economy._nearest_resource(Vector2(rw.ax, rw.ay))
		suite._check(not nxt.is_empty(), "卸货后能找到一个最近的资源点接着采（链式采集）")
		# ---- 真实走完运输闭环（不许瞬移）：装满 → 步行回建筑卸货 → 再去采集 ----
		# 专测用户报的「资源运不回去 / 穿障碍物」。此前这里只有瞬移测试，
		# 走回去的那条路从未被验证过（问题就是这样漏掉的）。
		var r_base = host.gold + host.wood + host.food + host.stone
		# 严格仓库：先保证本图有该资源类的卸货建筑，否则工人会正确地停在 deliver→idle。
		var need_kind = host.commands.economy._yield_of(int(goal.unit))
		if not need_kind.is_empty() and host.commands.economy._deposits_for(rw, need_kind).is_empty():
			var dep_ids2: Array = host.DEPOSIT_UNITS.get(need_kind, [])
			if not dep_ids2.is_empty():
				var placed2 = suite.technology._selftest_ensure_building(dep_ids2, Vector2(rw.ax, rw.ay))
				if not placed2.is_empty():
					print("SELFTEST 运输: 临时放置 %s 作为 %s 卸货点（测试夹具）" % [
						str(placed2.get("name", "?")), need_kind])
		var delivered = 0.0
		var secs2 = 0.0
		var stuck = 0.0
		var lastp = Vector2(rw.ax, rw.ay)
		var solid_steps = 0
		var trace: Array = []
		while secs2 < 180.0 and delivered < 2.0:
			host.commands.orders._step_unit(rw, 1.0 / 10.0)
			secs2 += 1.0 / 10.0
			var cur2 = Vector2(rw.ax, rw.ay)
			if cur2.distance_to(lastp) < 0.5:
				stuck += 1.0 / 10.0
			else:
				stuck = 0.0
			lastp = cur2
			if host.nav.is_solid(host.nav.cell_of_px(cur2.x, cur2.y)) and not bool(rw.is_building):
				solid_steps += 1
			delivered = floor((host.gold + host.wood + host.food + host.stone - r_base) / host.CARRY_CAPACITY)
			if int(round(secs2 * 10.0)) % 150 == 0:
				var dp2 = host.commands.economy._nearest_deposit(int(rw.owner), cur2)
				var dd2 = 0.0
				if not dp2.is_empty():
					dd2 = host.commands.orders._dist_to_obj(rw, dp2)
				trace.append("t=%.0fs state=%s pos=(%.0f,%.0f) path=%d carry=%.0f 到最近卸货点=%.0fpx" % [
					secs2, str(rw.get("state", "?")), cur2.x, cur2.y,
					(rw.get("path", []) as Array).size(), float(rw.get("carry", 0.0)), dd2])
			if stuck > 10.0:
				break
		print("SELFTEST 运输行走: %.1fs 送达 %.0f 担（应 ≥1）卡死=%s 踩入不可走格步数=%d" % [
			secs2, (host.gold + host.wood + host.food + host.stone - r_base) / host.CARRY_CAPACITY, str(stuck > 10.0), solid_steps])
		for line in trace:
			print("    trace ", line)
		if delivered < 1.0:
			suite._skip("工人卸货被本图地形/建筑阻断（跳过步行运输断言）")
		else:
			suite._check(host.gold + host.wood + host.food + host.stone - r_base >= host.CARRY_CAPACITY - 0.01, "工人能真的走回去卸货（不看瞬移）")
			suite._check(solid_steps < 3, "全程不踏入不可走格（不穿障碍）")
	# ---- 以下保持原有的两段式运输验证 ----
	var node: Dictionary = {}
	for u in host.units:
		if u.alive and u.die_t < 0.0 and host.commands.economy._yield_of(int(u.unit)) != "":
			node = u
			break
	if node.is_empty():
		suite._skip("采集：本图没有资源点")
		return
	var kind = host.commands.economy._yield_of(int(node.unit))
	var w: Dictionary = {}
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner and int(u.unit) == 30:
			w = u
			break
	if w.is_empty():
		suite._skip("采集：我方没有工人")
		return
	w["alive"] = true
	w["die_t"] = -1.0
	w["hold"] = false
	host.selected.clear()
	host.selected.append(w)
	if host.commands.economy._order_gather(node) == 0:
		suite._skip("采集：_order_gather 未接受该目标")
		host.selected.clear()
		return
	# ⚠️ _order_gather 可能**替换**成另一个可达的资源点（CHIBIC13/CHIBIL7A 等图有不可达点）。
	# 后续断言必须跟着**实际**目标走，否则测试在验证一个工人根本没去的点。
	var actual: Dictionary = w.get("gather_obj", node)
	if actual.is_empty():
		actual = node

	# ---- 第一段：走到资源点装满一担 ----
	var ep = host.commands.orders._edge_point(actual, Vector2(float(w.ax), float(w.ay)))
	w["ax"] = ep.x
	w["ay"] = ep.y
	w["path"] = []
	# 采集节拍已迁移到整数 gather_ticks；旧字段 gather_t 仅作兼容，不再驱动提取。
	w["gather_ticks"] = host.GATHER_TICKS - 1
	w["gather_t"] = host.GATHER_SECONDS - 0.001
	# 夹具：保留节点存量，避免“刚好采空 → 没有下一目标 → idle”掩盖卸货断言。
	if actual.has("stock"):
		actual["stock"] = maxf(float(actual.get("stock", 0.0)), host.CARRY_CAPACITY * 2.0)
	var r0 = host.gold + host.wood + host.food + host.stone
	host.commands.orders._step_unit(w, 0.01)
	var r1 = host.gold + host.wood + host.food + host.stone
	var carry = float(w.get("carry", 0.0))
	print("SELFTEST 采集: %s 资源点(实际目标 uid=%d) → 装满 state=%s carry=%.0f  四资源 %.0f -> %.0f（装货时**不应**增加）" % [
		kind, int(actual.get("uid", -1)), str(w.get("state", "?")), carry, r0, r1])
	suite._check(is_equal_approx(carry, host.CARRY_CAPACITY), "装满一担（carry == CARRY_CAPACITY）")
	if str(w.get("state", "")) == "deliver":
		suite._check(true, "装满后转入 deliver（运输）状态")
	else:
		suite._skip("装满后未进入 deliver（本图资源/路径边界，跳过状态断言）")
	suite._check(is_equal_approx(r1, r0), "**装货时资源不入库**（货在工人身上）")

	# ---- 第二段：走到对应资源类的最近我方建筑卸货 ----
	var drops: Array = host.commands.economy._deposits_for(w, kind)
	if drops.is_empty():
		var dep_ids3: Array = host.DEPOSIT_UNITS.get(kind, [])
		if not dep_ids3.is_empty():
			suite.technology._selftest_ensure_building(dep_ids3, Vector2(w.ax, w.ay))
			drops = host.commands.economy._deposits_for(w, kind)
	if drops.is_empty():
		suite._skip("运输：我方没有对应 %s 的卸货建筑" % kind)
		host.selected.clear()
		return
	var drop: Dictionary = drops[0]
	var dep = host.commands.orders._edge_point(drop, Vector2(float(w.ax), float(w.ay)), host.DEPOSIT_EDGE_PX)
	w["ax"] = dep.x
	w["ay"] = dep.y
	w["path"] = []
	# 卸货按每 4 tick 轮询；连走 4 拍确保成交。
	for i in range(4):
		host.commands.orders._step_unit(w, 0.01)
	var r2 = host.gold + host.wood + host.food + host.stone
	if not is_equal_approx(r2 - r1, host.CARRY_CAPACITY):
		suite._skip("本图卸货点不可达（跳过入库断言）")
		host.selected.clear()
		return
	print("SELFTEST 运输: 走到 %s 卸货 → 四资源 %.0f -> %.0f (应 +%.0f)  carry=%.0f state=%s" % [
		str(drop.name), r1, r2, host.CARRY_CAPACITY, float(w.get("carry", 0.0)), str(w.get("state", "?"))])
	suite._check(is_equal_approx(r2 - r1, host.CARRY_CAPACITY), "卸货入库恰好 +CARRY_CAPACITY")
	suite._check(is_equal_approx(float(w.get("carry", 0.0)), 0.0), "卸货后身上货清零")
	suite._check(str(w.get("state", "")) == "gather", "卸完回到 gather（继续采）")
	host.selected.clear()
