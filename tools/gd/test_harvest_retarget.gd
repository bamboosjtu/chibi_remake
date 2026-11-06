extends SceneTree
## R15 回归：自动转采以工人当前位置+有效视野收集候选，按实际路径长度选最近；
## 同距顺序稳定（先 y 后 x）。首派多人采集的替代资源分配沿用同一规则。
var sim: Node2D
var template: Dictionary
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
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
	sim.decor_targets = []
	sim.decor_cells = {}
	sim.player_owner = 3

func anchor(cell: Vector2i) -> Vector2:
	return sim.nav.anchor_of(cell.x, cell.y)

func make_worker(cell: Vector2i, vision := 8.0) -> Dictionary:
	var w: Dictionary = template.duplicate(true)
	w.uid = 1; w.owner = 3; w.unit = 30
	w.is_building = false; w.map_object = false; w.alive = true; w.die_t = -1.0
	w.state = "idle"; w.path = []; w.pi = 0; w.target = null
	w.officer = {}; w.group_officer = -1; w.attached = false
	w.confused_t = 0; w.haste_t = 0; w.slow_t = 0; w.farsight_t = 0; w.hidden_t = 0
	w.carry = 0.0; w.carry_kind = ""; w.gather_obj = null; w.gather_ticks = 0
	w.vision = vision
	var p := anchor(cell)
	w.ax = p.x; w.ay = p.y; w.A = cell.x; w.B = cell.y
	return w

func make_resource(uid: int, cell: Vector2i) -> Dictionary:
	var r := {
		"uid": uid, "owner": 0, "unit": 22, "alive": true, "die_t": -1.0,
		"is_building": true, "map_object": true, "decor": false, "site": false,
		"w": 136, "h": 96, "name": "铁矿",
		"stock": 500.0, "stock_max": 500.0,
		"occupied_cells": [cell],
	}
	var p := anchor(cell)
	r.ax = p.x; r.ay = p.y; r.A = cell.x; r.B = cell.y
	return r

func install(list: Array) -> void:
	sim.units = list
	sim.commands.world._rebuild_unit_index()

func run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false); scene.cli_mode = true
	template = scene.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == scene.player_owner)[0].duplicate(true)
	scene.free()

	# 旧资源在 14 格外（616px > 352px 视野）；新资源在 4 格内，必须选视野内的。
	blank()
	var worker := make_worker(Vector2i(25, 10), 8.0)
	var far := make_resource(10, Vector2i(11, 10))
	var near := make_resource(11, Vector2i(21, 10))
	install([worker, far, near])
	var previous := {"unit": 22, "alive": false, "die_t": 0.0, "ax": anchor(Vector2i(11, 10)).x, "ay": anchor(Vector2i(11, 10)).y}
	assert(sim.harvesting.next_target(worker, previous), "R15: 视野内存在可达同类资源时应转采")
	assert(is_same(worker.gather_obj, near), "R15: 不能按旧资源位置转采到视野外")
	assert(Vector2(worker.ax, worker.ay).distance_to(Vector2(far.ax, far.ay)) > worker.vision * sim.tile_w, "夹具：旧资源应在视野外")

	# 远视计谋扩大有效视野后，原本超出 8 格的资源应进入候选。
	blank()
	worker = make_worker(Vector2i(14, 10), 8.0)
	var ten_cells := make_resource(20, Vector2i(24, 10))
	install([worker, ten_cells])
	sim.decor_targets = [ten_cells]
	previous = {"unit": 22, "alive": false, "die_t": 0.0, "ax": anchor(Vector2i(4, 10)).x, "ay": anchor(Vector2i(4, 10)).y}
	assert(not sim.harvesting.next_target(worker, previous), "R15: 10 格资源超出普通视野时不应转采")
	worker.farsight_t = 800
	assert(sim.harvesting.next_target(worker, previous), "R15: 远视（10 格）应纳入转采候选")
	assert(is_same(worker.gather_obj, ten_cells), "R15: 远视后应选中该资源")

	# 路径代价：直线更近的资源被墙隔开，必须选实际路径更短的一侧。
	blank()
	worker = make_worker(Vector2i(10, 10), 8.0)
	var behind_wall := make_resource(30, Vector2i(12, 10))
	var same_side := make_resource(31, Vector2i(10, 14))
	for y in range(0, 40):
		if y != 20:
			sim.nav.block(Vector2i(11, y))      # 只留 y=20 的绕行口
	install([worker, behind_wall, same_side])
	var chosen: Dictionary = sim.commands.economy._nearest_harvest_by_path(worker, "stone")
	assert(not chosen.is_empty(), "R15: 两侧资源都应可达")
	assert(is_same(chosen.object, same_side), "R15: 应按路径长度而不是直线距离选择（实际 %s）" % str(chosen.object.get("uid", -1)))

	# 首派多人的替代资源分配：以工人视野为准，不再按原资源点 8 格。
	blank()
	worker = make_worker(Vector2i(30, 10), 8.0)
	var origin := make_resource(40, Vector2i(20, 10))
	var alt_outside_worker_vision := make_resource(41, Vector2i(14, 10))
	install([worker, origin, alt_outside_worker_vision])
	assert(Vector2(worker.ax, worker.ay).distance_to(Vector2(alt_outside_worker_vision.ax, alt_outside_worker_vision.ay)) > worker.vision * sim.tile_w)
	assert(sim.commands.economy._nearby_same_resource(origin, worker, {}).is_empty(), "R15: 替代资源也必须在工人有效视野内")
	var alt_inside := make_resource(42, Vector2i(34, 10))
	install([worker, origin, alt_outside_worker_vision, alt_inside])
	assert(is_same(sim.commands.economy._nearby_same_resource(origin, worker, {}), alt_inside), "R15: 视野内替代资源应可分配")
	# Explicit dense-field fallback must also preserve ordinary mineral fallback.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0: sim.nav.block(Vector2i(20 + dx, 10 + dy))
	sim.selected = [worker]
	assert(sim.commands.orders._edge_interaction_path(worker, origin).is_empty())
	assert(sim.commands.economy._order_gather(origin) == 1 and is_same(worker.gather_obj, alt_inside), "R15: explicit inaccessible mineral keeps vision-limited alternative assignment")
	print("HARVEST RETARGET PASS worker-centred vision / farsight / path cost / alternative assignment")
	done = true
	sim.free()
	await process_frame
	quit(0)
