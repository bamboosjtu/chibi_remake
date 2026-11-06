extends RefCounted
## Development assertions; shipped for --selftest candidate validation.
var host: Node2D
var _suite: WeakRef
var suite: RefCounted:
	get: return _suite.get_ref()

func _init(battle: Node2D, runner: RefCounted) -> void:
	host = battle
	_suite = weakref(runner) if runner != null else null

func _selftest_naval() -> void:
	print("SELFTEST naval: water_layer=%s 水面格=%d" % [str(host.nav.has_water), host.commands.world._water_cell_count()])
	if not host.nav.has_water:
		suite._skip("水战：本图没有水面数据（waterWalkable）")
		return
	suite._check(host.nav.has_water, "水面层已建立（waterWalkable）")
	# 找一支我方陆军 + 离它最近的通航水面格
	var land_unit: Dictionary = {}
	for u in host.units:
		if bool(u.get("alive", false)) and not bool(u.is_building) and int(u.get("owner", -1)) == host.player_owner \
				and not host.commands.military._is_naval(u) and not bool(u.get("attached", false)):
			land_unit = u
			break
	if land_unit.is_empty():
		suite._skip("水战：我方没有陆军可测试装载")
		return
	# 从陆军所在格做一次陆地 BFS，找**陆路可达的最近海岸**，再把船停到它旁边的水面。
	# 只按格距选“最近水面”会选到孤水/对岸，测试就会把不可达误判成装载逻辑坏。
	var start = host.nav.cell_of_px(land_unit.ax, land_unit.ay)
	var queue: Array = [start]
	var seen = {start: true}
	var head = 0
	var ship_cell = Vector2i(-1, -1)
	while head < queue.size() and ship_cell.x < 0:
		var c: Vector2i = queue[head]
		head += 1
		var waters: Array = []
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n = Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= int(host.map_data.rows) or n.y >= int(host.map_data.cols):
					continue
				# R04：船是 4 格占位，必须挑身体完全落在水面、且确实能停下的靠岸格；
				# 否则 _spawn_unit 会为了合法船体把船挪离岸边，装载距离超出 80px。
				if host.nav.is_water(n) and not host.nav.is_solid(n, 1) and host.commands.world._unit_placement_free(n, host.TRANSPORT_UNIT, 1, -1):
					waters.append(n)
		if not waters.is_empty():
			ship_cell = waters[0]
			break
		for n in host.nav.neighbors(c):
			if seen.has(n) or host.nav.is_solid(n, 0):
				continue
			seen[n] = true
			queue.append(n)
	if ship_cell.x < 0:
		suite._skip("水战：本图找不到陆路可达的海岸")
		return
	var sp = host.nav.anchor_of(ship_cell.x, ship_cell.y)
	if not host.commands.world._spawn_unit(host.TRANSPORT_UNIT, host.player_owner, sp.x, sp.y):
		suite._skip("水战：运输船图集缺失，无法生成测试船")
		return
	var ship: Dictionary = host.units.back()
	suite._check(host.nav.is_water(host.nav.cell_of_px(ship.ax, ship.ay)), "运输船落在水面格上")
	# 水面寻路：船至少能走到 8 格外的另一处水面
	# 从船所在水域做 BFS，找**同一连通水面**里 8 格外的格子；不按直线偏移猜，
	# 否则堤岸把水面切成两块时会把“本来就不连通”误判成寻路失败。
	var far_cell = Vector2i(-1, -1)
	var qwater: Array = [ship_cell]
	var seen_water = {ship_cell: true}
	var wh = 0
	while wh < qwater.size():
		var c2: Vector2i = qwater[wh]
		wh += 1
		if c2 != ship_cell and maxi(absi(c2.x - ship_cell.x), absi(c2.y - ship_cell.y)) >= 8:
			far_cell = c2
			break
		for n2 in host.nav.neighbors(c2):
			if seen_water.has(n2) or not host.nav.is_water(n2) or host.nav.is_solid(n2, 1):
				continue
			seen_water[n2] = true
			qwater.append(n2)
	if far_cell.x >= 0:
		var wp = host.nav.anchor_of(far_cell.x, far_cell.y)
		var sea_path = host.nav.find_path(Vector2(ship.ax, ship.ay), wp, true, 1, -1, int(ship.get("unit", -1)))
		print("SELFTEST naval: 船到 %s 的水面路径段=%d（应 >0）" % [str(far_cell), sea_path.size()])
		suite._check(sea_path.size() > 0, "水军按水面层寻路可达另一处水面")
	else:
		suite._skip("水战：本图没有 8 格外的连通水面")
	# 陆军上船：靠近 → 附着
	host.selected = [land_unit]
	var ordered = host.commands.orders._order_board(ship)
	suite._check(ordered == 1, "上船命令接受陆军（模式 0xC）")
	var steps = 0
	while steps < 3000 and not bool(land_unit.get("attached", false)):
		host.commands.orders._step_unit(land_unit, 1.0 / 30.0)
		steps += 1
		if steps % 300 == 0:
			print("SELFTEST naval trace: t=%.0fs state=%s path=%d dist=%.0f 反馈=%s" % [
				float(steps) / 30.0, str(land_unit.get("state", "?")),
				(land_unit.get("path", []) as Array).size(), host.commands.orders._dist_to_obj(land_unit, ship), host.feedback_text])
	print("SELFTEST naval: 上船用了 %.1f 秒 attached=%s 载员=%d loaded=%s" % [
		float(steps) / 30.0, str(bool(land_unit.get("attached", false))),
		int(ship.get("carry_n", 0)), str(bool(ship.get("loaded", false)))])
	suite._check(bool(land_unit.get("attached", false)), "陆军靠近运输船后自动装载（attached）")
	suite._check(int(ship.get("carry_n", 0)) == 1, "运输船载员 +1（+0x168）")
	suite._check(bool(ship.get("loaded", false)), "运输船装载标志置位（+0x164）")
	suite._check(is_equal_approx(float(ship.get("carry_hp", 0.0)), float(land_unit.hp)), "载员 HP 累计（+0x16C）")
	# 下船：点船附近陆地 → 复位到最近可走陆地
	var land_cell = Vector2i(-1, -1)
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c3 = Vector2i(ship_cell.x + dx, ship_cell.y + dy)
				if c3.x < 0 or c3.y < 0 or c3.x >= int(host.map_data.rows) or c3.y >= int(host.map_data.cols):
					continue
				if host.nav.is_water(c3) or host.nav.is_solid(c3, 0):
					continue
				land_cell = c3
				break
			if land_cell.x >= 0:
				break
		if land_cell.x >= 0:
			break
	if land_cell.x < 0:
		suite._skip("水战：船附近 6 格内没有可登陆陆地")
		return
	host.selected = [ship]
	var lp = host.nav.anchor_of(land_cell.x, land_cell.y)
	var unloaded = host.commands.orders._order_unload(ship, lp)
	for tick in range(4):
		host.commands.orders._step_unit(ship, 1.0 / 30.0)
	print("SELFTEST naval: 下船 %d 支 → attached=%s 载员=%d 落点=(%d,%d) 水面=%s" % [
		unloaded, str(bool(land_unit.get("attached", false))), int(ship.get("carry_n", 0)),
		int(land_unit.A), int(land_unit.B), str(host.nav.is_water(host.nav.cell_of_px(land_unit.ax, land_unit.ay)))])
	suite._check(unloaded == 1, "下船命令被接受（模式 0xD）")
	suite._check(not bool(land_unit.get("attached", false)), "下船后脱离运输船")
	suite._check(int(ship.get("carry_n", 0)) == 0 and not bool(ship.get("loaded", false)), "船载员与装载标志清零")
	suite._check(not host.nav.is_water(host.nav.cell_of_px(land_unit.ax, land_unit.ay)), "被载单位复位到陆地格（不是水面）")
	host.selected.clear()

func _selftest_gate_near(c: Vector2i, radius: int) -> bool:
	var cols = int(host.map_data.cols)
	for id in host.nav.gate_cells.keys():
		var gid = int(id)
		var a = int(gid / cols)
		var b = int(gid % cols)
		if maxi(absi(a - c.x), absi(b - c.y)) <= radius:
			return true
	return false

## 自检夹具：找到我方已建成的指定建筑；没有就在锚点附近放一座（只在 --selftest 使用）。
## 严格仓库/科技门禁都要求真实建筑与真实选择，测试不能假设每张图都恰好有这些建筑。

func _diag_nav() -> void:
	print("DIAG map=%s rows=%d cols=%d tileW=%.0f" % [host.map_id, int(host.map_data.rows), int(host.map_data.cols), host.tile_w])
	var workers: Array = []
	for u in host.units:
		if u.alive and not u.is_building and int(u.owner) == host.player_owner and int(u.unit) == 30:
			workers.append(u)
	print("DIAG 我方工人=%d" % workers.size())
	for w in workers:
		var c: Vector2i = host.commands.orders._cell_of_px(float(w.ax), float(w.ay))
		var nw: Vector2i = host.nav.near_walkable(c)
		print("DIAG 工人 uid=%d px=(%.0f,%.0f) cell=(%d,%d) solid=%s → near_walkable=(%d,%d) solid=%s 位移=%d" % [
			int(w.uid), float(w.ax), float(w.ay), c.x, c.y, str(host.nav.is_solid(c)),
			nw.x, nw.y, str(host.nav.is_solid(nw)), maxi(absi(nw.x - c.x), absi(nw.y - c.y))])
	for o in host.units:
		if not o.alive or host.commands.economy._yield_of(int(o.unit)) == "":
			continue
		var oc: Vector2i = host.commands.orders._cell_of_px(float(o.ax), float(o.ay))
		var onw: Vector2i = host.nav.near_walkable(oc)
		var fp: Array = o.get("occupied_cells", [])
		print("DIAG 资源 uid=%d(%s) px=(%.0f,%.0f) cell=(%d,%d) solid=%s → near_walkable=(%d,%d) solid=%s 占地格=%d" % [
			int(o.uid), host.commands.economy._yield_of(int(o.unit)), float(o.ax), float(o.ay), oc.x, oc.y, str(host.nav.is_solid(oc)),
			onw.x, onw.y, str(host.nav.is_solid(onw)), fp.size()])
		if not workers.is_empty():
			var w0: Dictionary = workers[0]
			var wc: Vector2i = host.nav.near_walkable(host.commands.orders._cell_of_px(float(w0.ax), float(w0.ay)))
			var pth = host.commands.orders._path_to(w0, Vector2(float(o.ax), float(o.ay)), false)
			print("DIAG   从工人到该资源：path=%d  起点solid=%s 终点solid=%s 起==终=%s" % [
				pth.size(), str(host.nav.is_solid(wc)), str(host.nav.is_solid(onw)), str(wc == onw)])
			var ids = host.nav.astar.get_id_path(host.nav._id(wc), host.nav._id(onw))
			print("DIAG   astar.get_id_path 长度=%d（<2 即不可达）" % ids.size())
	# 统计：地形本身封了多少、建筑占地又封了多少
	var walk: Array = host.map_data.get("terrainWalkable", host.map_data.walkable)
	var terr = 0
	for i in range(walk.size()):
		if int(walk[i]) == 0:
			terr += 1
	var occ = 0
	for u in host.units:
		if bool(u.is_building) and bool(u.alive):
			occ += (u.get("occupied_cells", []) as Array).size()
	print("DIAG 地形封格=%d/%d (%.1f%%)  建筑占地累计=%d 格" % [
		terr, walk.size(), 100.0 * float(terr) / float(maxi(1, walk.size())), occ])

## 自检辅助：目标格附近是否有自动城门。城门格会被“友军规划”临时打开，
## 人工封闭块若压到城门就会漏出一个洞，near_walkable 会从洞里逃出去。
