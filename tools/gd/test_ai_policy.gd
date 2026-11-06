extends SceneTree
## R09/R10/R11 AI 回归：
##   · 敌对关系只认玩家方（多 AI 不互攻）；
##   · 撤退按群维护、消费历史攻击者、其他群照常进攻；
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
	sim.commands._rebuild_unit_index()
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
	var threat: Dictionary = sim.commands._nearest_enemy_threat(ai1)
	assert(not threat.is_empty() and int(threat.owner) == 3, "R09: AI 应把玩家当威胁，实际 %s" % str(threat.get("owner", -1)))
	var nearest: Dictionary = sim.commands._nearest_enemy(ai1, 99999.0)
	assert(not nearest.is_empty() and int(nearest.owner) == 3, "R09: AI 箭楼不能选其他 AI")
	assert(int(sim.commands._nearest_enemy(human, 99999.0).owner) == 2, "R09: 玩家仍可攻击最近的 AI")
	sim.commands.ai_order_assault(1)
	assert(str(ai1.state) == "attack" and int(ai1.target.owner) == 3, "R09: 普通进攻目标必须是玩家方")
	ai1.state = "idle"; ai1.target = null
	sim.commands._free_unit_at(sim.units.find(human))
	assert(sim.commands._nearest_enemy_threat(ai1).is_empty(), "R09: 没有玩家单位时 AI 不攻击其他 AI")
	sim.commands.ai_order_assault(1)
	assert(str(ai1.state) == "idle" and ai1.target == null, "R09: 多 AI 地图不得互攻")

	# ---- R10：撤退按群、消费历史攻击者、其他群照常进攻 ----
	blank()
	var a_leader := officer(make(10, 1, 31, Vector2i(10, 10)), 0)
	var a_member := make(11, 1, 32, Vector2i(10, 12))
	a_member.group_officer = 0
	var b_leader := officer(make(20, 1, 31, Vector2i(20, 20)), 1)
	var b_member := make(21, 1, 32, Vector2i(20, 22))
	b_member.group_officer = 1
	var attacker := make(30, 3, 32, Vector2i(35, 10))
	install([a_leader, a_member, b_leader, b_member, attacker])
	a_leader.last_attacker_uid = int(attacker.uid)
	var first: Dictionary = brain._retreat_step(1)
	assert(first.has(0) and not first.has(1), "R10: 只有受击群撤退 %s" % str(first))
	assert(a_leader.state == "move" and a_member.state == "move", "R10: 受击群向锚点收拢")
	assert(b_leader.state == "idle" and b_member.state == "idle", "R10: 未被攻击的群不撤退")
	assert(int(a_leader.last_attacker_uid) == -1 and int(a_member.last_attacker_uid) == -1, "R10: 触发后必须消费历史攻击记录")
	# 其他群仍能接受进攻命令。
	sim.commands.ai_order_assault(1, first.keys())
	assert(str(b_leader.state) == "attack" and str(b_member.state) == "attack", "R10: 撤退不应阻断其他群进攻")
	# 撤退恢复只看锚点命令结束，且同一历史攻击不能再次触发。
	a_leader.state = "idle"; a_member.state = "idle"
	assert(brain._retreat_step(1).is_empty(), "R10: 锚点空闲即恢复")
	assert(brain._retreat_step(1).is_empty() and a_leader.state == "idle", "R10: 恢复后不应因旧伤再次撤退")
	# 新伤害才再次触发；攻击者死亡/离场后不触发。
	a_leader.last_attacker_uid = int(attacker.uid)
	assert(brain._retreat_step(1).has(0), "R10: 新命中应再次撤退")
	a_leader.state = "idle"; a_member.state = "idle"
	brain._retreat_step(1)
	a_leader.last_attacker_uid = int(attacker.uid)
	sim.commands._kill(attacker)
	assert(brain._retreat_step(1).is_empty(), "R10: 攻击者死亡后不撤退")
	# 快照：新格式按群保存并通过校验；旧格式 int 迁移不假装仍在撤退。
	a_leader.state = "idle"; a_member.state = "idle"
	a_leader.last_attacker_uid = -1
	brain._retreat[1] = {0: 1}
	var snap: Dictionary = brain.snapshot()
	assert(brain.valid_snapshot(snap, {}, [], 100), "R10: 新撤退结构应通过快照校验")
	brain.restore(snap)
	assert(brain._retreat.get(1, {}).has(0), "R10: 撤退群号应可恢复")
	var legacy: Dictionary = snap.duplicate(true)
	legacy.retreat = {1: 1}
	assert(brain.valid_snapshot(legacy, {}, [], 100), "R10: 旧撤退字段应可迁移")
	brain.restore(legacy)
	assert(brain._retreat.get(1, {}) is Dictionary and brain._retreat[1].is_empty(), "R10: 旧 int 不定位群")
	print("AI RETREAT PASS per-group / other groups assault / consume old attacker / dead attacker / snapshot migration")

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
	assert(not sim.commands.ai_construction_commander(1).is_empty(), "R11: 补满 5 名工人后必须有施工队长")
	for w in workers:
		assert(int(w.group_officer) == 0, "R11: 补员必须进入施工编组")
	assert(int(gatherer.group_officer) == -1 and str(gatherer.state) == "gather", "R11: 不得抢走采集工人")
	assert(int(repairer.group_officer) == -1 and str(repairer.state) == "repair", "R11: 不得抢走修理工人")
	assert(sim.commands._construction_workers(captain).size() == 5, "R11: 施工队应为 5 名工人")
	# 原工人全部阵亡：队长仍空闲，新生产的工人应重新编入施工队。
	for w in workers:
		sim.commands._kill(w)
	var fresh := make(40, 1, 30, Vector2i(16, 10))
	sim.units.append(fresh)
	sim._index_units_size = sim.units.size()
	brain._worker_step(1)
	assert(int(fresh.group_officer) == 0, "R11: 阵亡后补出的工人必须重新进入施工编组")
	assert(sim.commands._construction_workers(captain).size() == 1, "R11: 新工人应成为施工队成员")
	print("AI WORKERS PASS replenishment enters construction group / gather-repair preserved / recover after wipe")
	done = true
	sim.free()
	await process_frame
	quit(0)
