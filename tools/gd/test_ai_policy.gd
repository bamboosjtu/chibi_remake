extends SceneTree
## R09/R10/R11 AI 回归：
##   · 敌对关系只认玩家方（多 AI 不互攻）；
##   · 按42次思考及明确撤退点调度，不根据历史攻击者凭空撤退；
##   · 补工必须进入施工编组，且不抢采集/修理工人。
var sim: Node2D
var template: Dictionary
var brain: RefCounted
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
	sim.visibility.setup(Vector2(1848, 500))
	sim.units = []
	sim.selected = []
	sim.player_owner = 3
	sim.scenario_sides = []
	brain = load("res://simulation/systems/ai.gd").new(sim)
	sim.ai = brain

func install(list: Array) -> void:
	sim.units = list
	sim.commands.world._rebuild_unit_index()
	sim.visibility.update(list, sim.player_owner)

func make(uid: int, owner: int, kind: int, cell: Vector2i) -> Dictionary:
	var u: Dictionary = template.duplicate(true)
	u.uid = uid; u.owner = owner; u.unit = kind
	u.is_building = false; u.map_object = false; u.alive = true; u.die_t = -1.0
	u.state = "idle"; u.path = []; u.pi = 0; u.target = null
	u.officer = {}; u.group_officer = -1; u.attached = false; u.aboard_uid = -1
	u.confused_t = 0; u.haste_t = 0; u.slow_t = 0; u.farsight_t = 0; u.hidden_t = 0
	u.hp = 1000.0; u.maxhp = 1000.0; u.base_maxhp = 1000.0
	u.attack = 20.0; u.attack_b = 0.0; u.atk_range = 1.0; u.defence = 0.0
	u.last_attacker_uid = -1
	u.carry = 0.0; u.carry_kind = ""; u.gather_obj = null; u.build_target = null; u.repair_target = null
	var p: Vector2 = sim.nav.anchor_of(cell.x, cell.y)
	u.ax = p.x; u.ay = p.y; u.A = cell.x; u.B = cell.y
	return u

func officer(unit: Dictionary, index: int) -> Dictionary:
	unit.officer = {"index": index, "level": 3, "tier": 2, "might": 90.0, "intellect": 90.0, "name": "测试将%d" % index}
	return unit

func run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var scene: Node2D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false); scene.cli_mode = true
	template = scene.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == scene.player_owner)[0].duplicate(true)
	scene.free()

	# ---- R09：AI 只把玩家方当威胁 ----
	blank()
	var ai1 := make(1, 1, 32, Vector2i(10, 10))
	var ai2 := make(2, 2, 32, Vector2i(11, 10))
	var human := make(3, 3, 32, Vector2i(15, 10))
	install([ai1, ai2, human])
	var threat: Dictionary = sim.commands.military._nearest_enemy_threat(ai1)
	assert(not threat.is_empty() and int(threat.owner) == 3, "R09: AI 应把玩家当威胁，实际 %s" % str(threat.get("owner", -1)))
	var nearest: Dictionary = sim.commands.military._nearest_enemy(ai1, 99999.0)
	assert(not nearest.is_empty() and int(nearest.owner) == 3, "R09: AI 箭楼不能选其他 AI")
	assert(int(sim.commands.military._nearest_enemy(human, 99999.0).owner) == 2, "R09: 玩家仍可攻击最近的 AI")
	sim.commands.military.ai_order_assault(1)
	assert(str(ai1.state) == "attack" and int(ai1.target.owner) == 3, "R09: 普通进攻目标必须是玩家方")
	ai1.state = "idle"; ai1.target = null
	sim.commands.world._free_unit_at(sim.units.find(human))
	assert(sim.commands.military._nearest_enemy_threat(ai1).is_empty(), "R09: 没有玩家单位时 AI 不攻击其他 AI")
	sim.commands.military.ai_order_assault(1)
	assert(str(ai1.state) == "idle" and ai1.target == null, "R09: 多 AI 地图不得互攻")

	# Research correction: a historical attacker is not a retreat destination.
	blank()
	var a_leader := officer(make(10, 1, 31, Vector2i(10, 10)), 0)
	var a_member := make(11, 1, 32, Vector2i(10, 12))
	a_member.group_officer = 0
	var b_member := make(21, 1, 32, Vector2i(20, 22))
	var attacker := make(30, 3, 32, Vector2i(35, 10))
	install([a_leader,a_member,b_member,attacker])
	a_leader.last_attacker_uid = int(attacker.uid)
	for thought in range(42): assert(brain._retreat_step(1).is_empty())
	assert(a_leader.state == "idle", "No explicit retreat point: damage history must not invent a retreat")
	var destination: Vector2 = sim.nav.anchor_of(4,4)
	assert(brain.set_retreat_point(1,destination))
	a_leader.target=attacker; a_leader.state="attack"
	a_member.target=attacker; a_member.state="attack"
	for thought in range(41): brain._retreat_step(1)
	assert(a_leader.state=="attack" and a_member.state=="attack")
	var snap: Dictionary=brain.snapshot()
	assert(brain.valid_snapshot(snap,{},[],100))
	brain.restore(snap)
	brain._retreat_step(1)
	assert(a_leader.state=="move" and a_member.state=="move", "42nd thought returns targeted units to the explicit destination")
	assert(b_member.state=="idle", "Untargeted units must retain their orders")
	assert(a_leader.path.back()==destination and a_member.path.back()==destination)
	assert(brain.snapshot().retreatClock[1]==0)
	var invalid: Dictionary=snap.duplicate(true)
	invalid.retreatPoints={1:["bad",1]}
	assert(not brain.valid_snapshot(invalid,{},[],100))
	var invalid_shape: Dictionary=snap.duplicate(true);invalid_shape.retreat={1:1}
	assert(not brain.valid_snapshot(invalid_shape,{},[],100))
	print("AI RETREAT PASS 42-thought clock / explicit point / targeted units / no invented retreat / current snapshot shape")

	# ---- R11：补工进入施工编组，且不抢采集/修理 ----
	blank()
	var captain := officer(make(1, 1, 31, Vector2i(10, 10)), 0)
	var workers: Array = []
	for i in range(5):
		workers.append(make(10 + i, 1, 30, Vector2i(12 + i, 10)))
	var gatherer := make(20, 1, 30, Vector2i(14, 20))
	gatherer.state = "gather"; gatherer.gather_obj = gatherer
	var repairer := make(21, 1, 30, Vector2i(15, 20))
	repairer.state = "repair"; repairer.repair_target = captain
	install([captain] + workers + [gatherer, repairer])
	brain._worker_step(1)
	assert(not sim.commands.economy.ai_construction_commander(1).is_empty(), "R11: 补满 5 名工人后必须有施工队长")
	for w in workers:
		assert(int(w.group_officer) == 0, "R11: 补员必须进入施工编组")
	assert(int(gatherer.group_officer) == -1 and str(gatherer.state) == "gather", "R11: 不得抢走采集工人")
	assert(int(repairer.group_officer) == -1 and str(repairer.state) == "repair", "R11: 不得抢走修理工人")
	assert(sim.commands.military._construction_workers(captain).size() == 5, "R11: 施工队应为 5 名工人")
	# 原工人全部阵亡：队长仍空闲，新生产的工人应重新编入施工队。
	for w in workers:
		sim.commands.military._kill(w)
	var fresh := make(40, 1, 30, Vector2i(16, 10))
	sim.units.append(fresh)
	sim._index_units_size = sim.units.size()
	brain._worker_step(1)
	assert(int(fresh.group_officer) == 0, "R11: 阵亡后补出的工人必须重新进入施工编组")
	assert(sim.commands.military._construction_workers(captain).size() == 1, "R11: 新工人应成为施工队成员")
	print("AI WORKERS PASS replenishment enters construction group / gather-repair preserved / recover after wipe")
	done = true
	sim.free()
	await process_frame
	quit(0)
