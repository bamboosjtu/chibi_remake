extends SceneTree
# REQ-003（review.md R-03）回归夹具：动态占地与路径失效。
#
# 验收（registry REQ-003）：行军期间建造/拆除/地形事件，单位不穿过新占地、
# 不原地无限重试。运行方式与 test_architecture.gd 相同：
#   隔离 APPDATA + godot --headless --path godot/chibi_remake \
#     --script ../../tools/gd/test_nav_invalidation.gd -- --noview
# 任何 assert 失败都会中断并以非零码退出。

var _done := false                                # 看门狗：断言失败中止 _run 后改由超时退出

func _initialize() -> void:
	# 断言失败会中止 _run、quit() 不再执行 —— 超时后按失败退出，不留挂死进程。
	create_timer(90.0).timeout.connect(func() -> void:
		if not _done:
			printerr("NAV-INV TIMEOUT: _run 未在时限内完成（断言失败即此表现）")
			quit(1))
	_run.call_deferred()

## 夹具辅助：取路径里第一个"不在单位脚下格"的路点（占地它才会挡住当前段）。
static func _wp_ahead(u: Dictionary, nav, wps: Array) -> Vector2i:
	var origin:=Vector2(float(u.ax),float(u.ay))
	var own: Vector2i=nav.cell_of_px(origin.x,origin.y)
	for wp in wps:
		for fraction in [0.25,0.5,0.75]:
			var point: Vector2=origin.lerp(wp,fraction)
			var cell: Vector2i=nav.cell_of_px(point.x,point.y)
			if cell!=own and cell!=nav.cell_of_px(wps.back().x,wps.back().y):return cell
		origin=wp
	return own

func _run() -> void:
	var nav = load("res://simulation/navigation/nav.gd").new()
	var walk := []
	walk.resize(48)
	walk.fill(1)
	var v0: int = nav.version
	nav.setup({"rows": 6, "cols": 8, "walkable": walk, "terrainWalkable": walk, "terrainW": 600, "terrainH": 300})
	assert(nav.version > v0)
	# 版本化：block / unblock / occupy 每次变更都递增（路径失效依据，REQ-003）
	var v1: int = nav.version
	nav.block(Vector2i(2, 3))
	assert(nav.version == v1 + 1)
	nav.unblock(Vector2i(2, 3))
	assert(nav.version == v1 + 2)
	nav.occupy([Vector2i(3, 3)], 1)
	assert(nav.version == v1 + 3)
	nav.occupy([Vector2i(3, 3)], -1)
	assert(nav.version == v1 + 4)

	# segment_clear_from 与 segment_clear 的差别：起点所在的格被跳过。
	# 场景 A —— 单位站在实心格里（贴墙角/旧实现留下）：必须允许它走出来。
	nav.block(Vector2i(2, 3))
	var inside: Vector2 = nav.anchor_of(2, 3)
	var escape: Vector2 = nav.anchor_of(1, 3)
	assert(nav.is_solid(Vector2i(2, 3)))
	assert(not nav.segment_clear(inside, escape))          # 旧判据：被自己的起点判死
	assert(nav.segment_clear_from(inside, escape))         # 新判据：跳过脚下 → 可逃离
	# 场景 B —— 前方（非脚下）出现新占地：必须拦下。
	var out: Vector2 = nav.anchor_of(1, 2)
	var ahead: Vector2 = nav.anchor_of(1, 3)
	assert(nav.segment_clear_from(out, ahead))
	nav.block(Vector2i(1, 3))
	assert(not nav.segment_clear_from(out, ahead))
	nav.unblock(Vector2i(1, 3))
	# 场景 C —— 空地直行：不拦。
	assert(nav.segment_clear_from(nav.anchor_of(0, 0), nav.anchor_of(3, 2)))
	print("NAV-INV PASS: version bumps, own-cell escape, ahead block, clear run")

	# ---- 世界级：main.tscn + 手动 _sim_step（与 test_architecture.gd 同法）----
	var game := root.get_node("Game")
	game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var mobiles := []
	for u in battle.units:
		if not u.is_building and u.alive and int(u.owner) == int(battle.player_owner):
			mobiles.append(u)
	assert(mobiles.size() >= 3)

	# 场景 D —— 行军中建筑落成压住当前路点：不穿实心格，重寻路绕行抵达原目的地。
	var mover: Dictionary = mobiles[0]
	mover.hold = true                      # 断开自动索敌，杜绝夹具外的状态干扰
	var from: Vector2i = battle.nav.near_walkable(battle.nav.cell_of_px(mover.ax, mover.ay))
	var mpos: Vector2 = battle.nav.anchor_of(from.x, from.y)
	mover.ax = mpos.x                      # 桩到锚点，保证 wps[0] 是"下一格"而不是自己
	mover.ay = mpos.y
	mover.A = from.x
	mover.B = from.y
	# 目的地：同列往下 5 格；先确认可达再下达，路径含多个路点。
	var dest: Vector2i = Vector2i(from.x, from.y + 5)
	assert(not battle.nav.is_solid(dest))
	var wps: Array = battle.nav.find_path(mpos, battle.nav.anchor_of(dest.x, dest.y), true)
	assert(not wps.is_empty())
	mover.state = "move"
	mover.path = wps
	mover.pi = 0
	mover.erase("repath_to")
	var wp1: Vector2i = _wp_ahead(mover, battle.nav, wps)
	assert(wp1 != dest, "夹具失效：第一个路点就是目的地，堵不住中途")
	var vAt: int = battle.nav.version
	battle.nav.occupy([wp1], 1)            # 模拟建筑落成，正好压住下一路点
	assert(battle.nav.version > vAt)
	assert(battle.nav.is_solid(wp1))
	var arrived := false
	var ever_blocked := false
	var max_blocked := 0
	for i in range(240):                   # 8 秒模拟步，手动推进
		battle.commands.world._sim_step(battle.SIM_DT)
		var c: Vector2i = battle.nav.cell_of_px(mover.ax, mover.ay)
		assert(not battle.nav.is_solid(c), "单位踏入实心格（REQ-003 核心判据）")
		ever_blocked = ever_blocked or int(mover.get("blocked_n", 0)) > 0
		max_blocked = maxi(max_blocked, int(mover.get("blocked_n", 0)))
		if mover.state == "idle" and battle.nav.cell_of_px(mover.ax, mover.ay) == dest:
			arrived = true
			break
	assert(ever_blocked, "夹具没触发阻挡，场景 D 无效")
	assert(max_blocked <= 2, "被堵计数越界：重寻路没有收敛")
	assert(arrived, "被堵后没有绕行抵达原目的地（repath_to 未生效）")
	assert(not mover.has("repath_to"), "repath_to 未被消费即残留")
	print("NAV-INV PASS: blocked mid-march -> repath around, arrives, never enters solid")

	# 场景 E —— 重寻路也不可达（目的地被封死）：弃单转 idle，不无限重试。
	# 目的地放远些 + 封它的 13×13 邻域，保证封圈不盖住出发点和第一路点。
	var giver: Dictionary = mobiles[1]
	giver.hold = true
	var g0: Vector2i = battle.nav.near_walkable(battle.nav.cell_of_px(giver.ax, giver.ay))
	var gpos: Vector2 = battle.nav.anchor_of(g0.x, g0.y)
	giver.ax = gpos.x
	giver.ay = gpos.y
	giver.A = g0.x
	giver.B = g0.y
	var gdest: Vector2i = Vector2i(clampi(g0.x, 0, int(battle.map_data.rows) - 1), clampi(g0.y + 8, 0, int(battle.map_data.cols) - 1))
	assert(not battle.nav.is_solid(gdest))
	var gw: Array = battle.nav.find_path(gpos, battle.nav.anchor_of(gdest.x, gdest.y), true)
	assert(not gw.is_empty())
	giver.state = "move"
	giver.path = gw
	giver.pi = 0
	var gwp: Vector2i = _wp_ahead(giver, battle.nav, gw)
	battle.nav.occupy([gwp], 1)            # 堵住当前段 → 触发重寻路
	# 再把目的地周边 13×13 全封死（超出 near_walkable 的 5 圈半径），重寻路必然失败。
	var mr: int = int(battle.map_data.rows)
	var mc: int = int(battle.map_data.cols)
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var q := Vector2i(clampi(gdest.x + dx, 0, mr - 1), clampi(gdest.y + dy, 0, mc - 1))
			if not battle.nav.is_solid(q):
				battle.nav.block(q)
	assert(battle.nav.is_solid(gdest))
	var gave_up := false
	for i in range(60):
		battle.commands.world._sim_step(battle.SIM_DT)
		var c2: Vector2i = battle.nav.cell_of_px(giver.ax, giver.ay)
		assert(not battle.nav.is_solid(c2), "弃单场景中踏入实心格")
		if giver.state == "idle":
			gave_up = true
			break
	assert(gave_up, "目的地被封死仍不弃单（原地无限重试）")
	assert(not giver.has("repath_to"), "弃单后 repath_to 残留，可能污染后续订单")
	print("NAV-INV PASS: unreachable destination -> gives up, no infinite retry")

	# 场景 F —— 站在实心格里的单位也能下单走出去（find_path 跳过脚下格判据）。
	var stuck: Dictionary = mobiles[2]
	stuck.hold = true
	var sc: Vector2i = battle.nav.near_walkable(battle.nav.cell_of_px(stuck.ax, stuck.ay))
	var target: Vector2i = sc
	var escape_ok := false
	for n in battle.nav.neighbors(sc):
		if not battle.nav.is_solid(n) and battle.commands.world._cell_unit(n).is_empty():
			target = n
			escape_ok = true
			break
	assert(escape_ok, "夹具失效：单位四周全实心")
	battle.nav.block(sc)                   # 把单位脚下封住，模拟贴墙角局面
	assert(battle.nav.is_solid(sc))
	var spos: Vector2 = battle.nav.anchor_of(sc.x, sc.y)
	stuck.ax = spos.x
	stuck.ay = spos.y
	stuck.A = sc.x
	stuck.B = sc.y
	stuck.state = "move"
	stuck.path = battle.nav.find_path(spos, battle.nav.anchor_of(target.x, target.y), true)
	assert(not stuck.path.is_empty(), "实心格起点的单位寻路失败：被自己的起点判死")
	var left := false
	for i in range(30):
		battle.commands.world._sim_step(battle.SIM_DT)
		if battle.nav.cell_of_px(stuck.ax, stuck.ay) != sc:
			left = true
			break
	assert(left, "站在实心格里的单位走不出去（被自己的起点判死）")
	print("NAV-INV PASS: unit standing in a solid cell can still walk out")

	battle.free()
	_done = true
	quit()
