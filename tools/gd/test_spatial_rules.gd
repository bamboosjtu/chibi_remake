extends SceneTree
## R05/R06 空间规则回归：
##   · 防叠让位必须连通，不能把单位瞬移过墙；
##   · 近战两格补偿必须检查双方之间的阻挡，不能隔墙扣血。
## 使用空白 40×40 夹具，不依赖真实地图资产。
var sim: Node2D
var template: Dictionary
var done := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func blank() -> void:
	if sim != null:
		sim.free()
	sim = load("res://main.gd").new()
	var walk: Array = []
	walk.resize(1600)
	walk.fill(1)
	sim.map_data = {"rows": 40, "cols": 40, "terrainW": 1848, "terrainH": 500, "tileW": 44, "walkable": walk, "terrainWalkable": walk, "units": {}}
	sim.nav.setup(sim.map_data)
	sim.units = []
	sim.selected = []

func position(u: Dictionary, c: Vector2i) -> void:
	var p: Vector2 = sim.nav.anchor_of(c.x, c.y)
	u.ax = p.x; u.ay = p.y; u.A = c.x; u.B = c.y

## 手工夹具直接替换 units 后必须重建 R13 占格索引（正常流程由 _place_unit 增量维护）。
func install(list: Array) -> void:
	sim.units = list
	sim.commands.world._rebuild_unit_index()

func make(uid: int, owner: int, kind: int, cell: Vector2i, hp := 1000.0) -> Dictionary:
	var u: Dictionary = template.duplicate(true)
	u.uid = uid; u.owner = owner; u.unit = kind
	u.is_building = false; u.map_object = false
	u.alive = true; u.die_t = -1.0
	u.state = "idle"; u.path = []; u.pi = 0; u.target = null
	u.officer = {}; u.group_officer = -1; u.attached = false; u.aboard_uid = -1
	u.confused_t = 0; u.haste_t = 0; u.slow_t = 0; u.farsight_t = 0; u.hidden_t = 0
	u.hp = hp; u.maxhp = hp; u.base_maxhp = hp
	position(u, cell)
	return u

func run() -> void:
	# 取一个真实单位字典作为字段模板（单位字段随版本增长，手写夹具容易漏键）。
	root.get_node("Game").current_map = "chibic1"
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false); scene.cli_mode = true
	template = scene.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == scene.player_owner)[0].duplicate(true)
	scene.free()

	# ---- R05：一圈封锁时不得让位到墙外 ----
	blank()
	var a := make(1, 1, 32, Vector2i(10, 10))
	var b := make(2, 1, 32, Vector2i(10, 10))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				sim.nav.block(Vector2i(10 + dx, 10 + dy))
	install([a, b])
	var old := Vector2(a.ax, a.ay)
	sim.commands.world._separate_unit(a)
	assert(Vector2(a.ax, a.ay) == old, "R05: 无连通空位时不能瞬移，位移=%f" % old.distance_to(Vector2(a.ax, a.ay)))
	assert(int(a.A) == 10 and int(a.B) == 10, "R05: 应保持原格")
	# 打开一个相邻格后，只能让位到**可连通**的相邻格。
	sim.nav.unblock(Vector2i(11, 10))
	for tick in range(20):
		var before:=Vector2(float(a.ax),float(a.ay))
		sim.commands.world._separate_unit(a)
		assert(before.distance_to(Vector2(a.ax,a.ay))<=sim.SPEED*sim.SIM_DT+0.001,"yield must not teleport")
		if int(a.A)==11 and int(a.B)==10:break
	assert(int(a.A) == 11 and int(a.B) == 10, "R05: 应让位到刚打开的相邻格")
	# 相邻格在等距交错网格里不一定互为 A* 邻点，用几何连通（离散采样）验收。
	assert(sim.nav.segment_clear_from(old, Vector2(a.ax, a.ay), 0), "R05: 相邻让位必须几何连通")

	# 一侧被墙封死、另一侧仍有通路：让位结果必须真实可达（不能只看最近空格）。
	blank()
	a = make(1, 1, 32, Vector2i(10, 10))
	b = make(2, 1, 32, Vector2i(10, 10))
	for cell in [Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9)]:
		sim.nav.block(cell)
	install([a, b])
	for tick in range(20):
		sim.commands.world._separate_unit(a)
		if Vector2i(int(a.A),int(a.B))!=Vector2i(10,10):break
	var new_cell := Vector2i(int(a.A), int(a.B))
	assert(new_cell != Vector2i(10, 10), "R05: 存在连通空位时应让位")
	assert(not sim.nav.find_path(old, Vector2(a.ax, a.ay), true).is_empty(), "R05: 绕行让位必须真实可达 new=%s" % [new_cell])

	# ---- R06：两格近战补偿不得穿透阻挡 ----
	blank()
	a = make(1, 3, 32, Vector2i(10, 10), 1000.0)
	b = make(2, 1, 32, Vector2i(12, 10), 1000.0)
	a.attack = 20.0; a.defence = 0.0; a.atk_range = 1.0; a.rate = 1000
	a.clips = {"walk": [[0, 1, 2]]}
	a.state = "attack"; a.target = b
	sim.nav.block(Vector2i(11, 10))
	install([a, b])
	var hp0 := float(b.hp)
	for tick in range(8):
		sim.commands.orders._step_unit_inner(a, sim.SIM_DT)
	assert(float(b.hp) == hp0, "R06: 中间有墙时近战不能扣血（hp %.1f → %.1f）" % [hp0, float(b.hp)])
	# 拆掉阻挡后同一距离应恢复命中（保留拥堵补偿的初衷）。
	sim.nav.unblock(Vector2i(11, 10))
	for tick in range(16):
		sim.commands.orders._step_unit_inner(a, sim.SIM_DT)
	assert(float(b.hp) < hp0, "R06: 无阻挡的两格近战仍应命中（hp %.1f）" % float(b.hp))

	# ---- R04：四格单位的整条路线不得让身体穿越封锁格 ----
	blank()
	a = make(1, 1, 37, Vector2i(10, 10))
	sim.nav.block(Vector2i(10, 11))
	install([a])
	var route: Array = sim.commands.orders._path_to(a, sim.nav.anchor_of(10, 18), true)
	assert(not route.is_empty(), "R04: 四格单位应能绕开封锁格到达目标")
	var body_collisions: Array = []
	for point in route:
		var anchor: Vector2i = sim.nav.cell_of_px(point.x, point.y)
		for c in sim.UnitFootprint.shape(37, anchor):
			if sim.nav.is_solid(c):
				body_collisions.append([anchor, c])
	assert(body_collisions.is_empty(), "R04: 路线身体不得压住封锁格 %s" % [str(body_collisions)])
	# 单格单位仍可穿过同一走廊（形状差异确实生效）。
	var walker := make(2, 1, 32, Vector2i(10, 10))
	install([walker])
	var single: Array = sim.commands.orders._path_to(walker, sim.nav.anchor_of(10, 18), true)
	assert(not single.is_empty(), "R04: 单格单位路线存在")

	# ---- R14：终点被占不能丢单，应就近停靠 ----
	blank()
	a = make(1, 3, 32, Vector2i(10, 10), 1000.0)
	b = make(2, 1, 32, Vector2i(11, 11), 1000.0)
	a.state = "move"
	a.path = [Vector2(b.ax, b.ay)]
	a.pi = 0
	install([a, b])
	sim.commands.orders._step_unit(a, sim.SIM_DT)
	assert(str(a.state) == "move", "R14: 终点被占后仍应保持移动命令")
	assert(not (a.path as Array).is_empty(), "R14: 应改道到附近合法落脚格")
	for tick in range(120):
		sim.commands.orders._step_unit(a, sim.SIM_DT)
		if str(a.state) == "idle":
			break
	assert(str(a.state) == "idle", "R14: 就近停靠后应结束移动")
	var stop := Vector2i(int(a.A), int(a.B))
	var occupied := Vector2i(int(b.A), int(b.B))
	assert(stop != occupied, "R14: 不能停在别人身上")
	assert(maxi(absi(stop.x - occupied.x), absi(stop.y - occupied.y)) <= 4, "R14: 应停靠在目的地附近 %s vs %s" % [stop, occupied])
	print("SPATIAL RULES PASS separation stays connected / melee respects blockers / multi-cell route body-free / occupied goal stops nearby")
	done = true
	sim.free()
	await process_frame
	quit(0)
