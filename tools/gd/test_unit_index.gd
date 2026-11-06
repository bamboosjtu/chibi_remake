extends SceneTree
## R13 回归：单位占格索引的正确性 + 规模成本。
## 评审基线（无视图、无 AI、静止单位）每 tick 单位更新均值：
##   100≈44.95ms / 200≈181.20ms / 400≈727.98ms / 800≈3152.79ms（平方级）。
## 本测试要求 800 单位仍低于最慢逻辑周期预算（100ms），并核对索引与全量扫描一致。
var sim: Node2D
var template: Dictionary
var done := false

const SCALES := [100, 200, 400, 800]

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

func install(list: Array) -> void:
	sim.units = list
	sim.commands._rebuild_unit_index()

func make(uid: int, owner: int, kind: int, cell: Vector2i) -> Dictionary:
	var u: Dictionary = template.duplicate(true)
	u.uid = uid; u.owner = owner; u.unit = kind
	u.is_building = false; u.map_object = false; u.alive = true; u.die_t = -1.0
	u.state = "idle"; u.path = []; u.pi = 0; u.target = null
	u.officer = {}; u.group_officer = -1; u.attached = false; u.aboard_uid = -1
	u.confused_t = 0; u.haste_t = 0; u.slow_t = 0; u.farsight_t = 0; u.hidden_t = 0
	var p: Vector2 = sim.nav.anchor_of(cell.x, cell.y)
	u.ax = p.x; u.ay = p.y; u.A = cell.x; u.B = cell.y
	return u

## 暴力扫描（旧实现口径），只用于核对索引结果。
func brute_cell_unit(cell: Vector2i, exclude_uid: int, layer: int) -> bool:
	for other in sim.units:
		if not bool(other.get("alive", false)) or float(other.get("die_t", -1)) >= 0.0: continue
		if bool(other.get("is_building", false)) or bool(other.get("attached", false)): continue
		if int(other.get("uid", -1)) == exclude_uid: continue
		if sim.commands._nav_layer(other) != layer: continue
		if cell in sim.commands._footprint_cells(other):
			return true
	return false

func verify_index() -> void:
	for a in range(0, 40, 3):
		for b in range(0, 40, 5):
			var cell := Vector2i(a, b)
			for layer in [0]:
				var indexed: bool = not sim.commands._cell_unit(cell, -1, layer).is_empty()
				var brute: bool = brute_cell_unit(cell, -1, layer)
				assert(indexed == brute, "R13: 索引与全量扫描不一致 cell=%s layer=%d (%s != %s)" % [cell, layer, indexed, brute])

func run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false); scene.cli_mode = true
	template = scene.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == scene.player_owner)[0].duplicate(true)
	scene.free()

	var timings: Array = []
	for n in SCALES:
		blank()
		for i in range(n):
			sim.units.append(make(i, 1 + int(i / 200), 32, Vector2i(i % 38 + 1, i / 38 + 1)))
		sim.commands._rebuild_unit_index()
		verify_index()
		# 预热后取三批 10 tick 的中位数：排除冷启动与一次性的系统负载抖动，
		# 持续超预算仍会被 100ms 断言拦下。
		for tick in range(3):
			for body in sim.units:
				sim.commands._step_unit(body, sim.SIM_DT)
		var samples: Array = []
		for batch in range(3):
			var begin: int = Time.get_ticks_usec()
			for tick in range(10):
				for body in sim.units:
					sim.commands._step_unit(body, sim.SIM_DT)
			samples.append(float(Time.get_ticks_usec() - begin) / 10000.0)
		samples.sort()
		var each_ms: float = float(samples[1])
		timings.append({"units": n, "idle_tick_ms": each_ms})
		print("R13 units=%d idle_tick_ms=%.2f samples=%s" % [n, each_ms, str(samples)])
	var worst: float = float(timings[timings.size() - 1].idle_tick_ms)
	assert(worst < 100.0, "R13: 800 单位每 tick 单位更新均值 %.2fms 超过 100ms 预算" % worst)

	# 增量正确性：移动、死亡、装载、落位索引都跟得上。
	blank()
	var a := make(1, 1, 32, Vector2i(10, 10))
	var b := make(2, 1, 34, Vector2i(12, 10))
	install([a, b])
	assert(not sim.commands._cell_unit(Vector2i(10, 10), -1, 0).is_empty())
	assert(not sim.commands._cell_unit(Vector2i(11, 9), -1, 0).is_empty(), "四格单位的后排格也应入索引")
	a.ax = sim.nav.anchor_of(20, 10).x; a.ay = sim.nav.anchor_of(20, 10).y
	a.A = 20; a.B = 10
	sim.commands._place_unit(a)
	assert(sim.commands._cell_unit(Vector2i(10, 10), -1, 0).is_empty(), "移动后旧格必须释放")
	assert(not sim.commands._cell_unit(Vector2i(20, 10), -1, 0).is_empty(), "移动后新格必须占用")
	b.attached = true
	sim.commands._index_sync(b)
	assert(sim.commands._cell_unit(Vector2i(12, 10), -1, 0).is_empty(), "装载后身体格必须释放")
	assert(sim.commands._cell_unit(Vector2i(11, 9), -1, 0).is_empty(), "装载后四格单位后排也要释放")
	b.attached = false
	sim.commands._index_sync(b)
	assert(not sim.commands._cell_unit(Vector2i(12, 10), -1, 0).is_empty(), "下船后身体格重新占用")
	sim.commands._kill(a)
	assert(sim.commands._cell_unit(Vector2i(20, 10), -1, 0).is_empty(), "阵亡后身体格必须释放")
	sim.commands._free_unit_at(sim.units.find(b))
	assert(sim.commands._cell_unit(Vector2i(12, 10), -1, 0).is_empty(), "移除后身体格必须释放")
	print("UNIT INDEX PASS timing=%s / 800 budget / move-kill-attach-free incremental integrity" % [str(timings)])
	done = true
	sim.free()
	await process_frame
	quit(0)
