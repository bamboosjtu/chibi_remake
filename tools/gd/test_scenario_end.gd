extends SceneTree
## R12 回归：任务 29 的专属出口 = 参战方列表第 3 方（chibic13 为 owner 2）清空即胜，
## 即使第 2 方仍在；该分支必须与通用歼灭胜利分开（objective_done + 任务锁存）。
var sim: Node2D
var template: Dictionary
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func blank() -> void:
	sim = load("res://main.gd").new()
	var walk: Array = []
	walk.resize(1600)
	walk.fill(1)
	sim.map_data = {"rows": 40, "cols": 40, "terrainW": 1848, "terrainH": 500, "tileW": 44, "walkable": walk, "terrainWalkable": walk, "units": {}}
	sim.nav.setup(sim.map_data)
	sim.units = []
	sim.selected = []
	sim.player_owner = 3
	sim.scenario_sides = [{"owner": 3}, {"owner": 1}, {"owner": 2}]
	sim.scenario_mission = 29
	sim.rules = load("res://simulation/systems/scenario_rules.gd").new(sim)

func make(uid: int, owner: int, kind: int, cell: Vector2i, building := false) -> Dictionary:
	var u: Dictionary = template.duplicate(true)
	u.uid = uid; u.owner = owner; u.unit = kind
	u.is_building = building; u.map_object = false; u.alive = true; u.die_t = -1.0
	u.state = "idle"; u.path = []; u.pi = 0; u.target = null
	u.officer = {}; u.group_officer = -1; u.attached = false
	u.hp = 1000.0; u.maxhp = 1000.0; u.base_maxhp = 1000.0
	var p: Vector2 = sim.nav.anchor_of(cell.x, cell.y)
	u.ax = p.x; u.ay = p.y; u.A = cell.x; u.B = cell.y
	return u

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

	# 空白夹具：第 2 方存活、第 3 方仍有建筑时不能结束；清空第 3 方后专属胜利。
	blank()
	var player := make(1, 3, 32, Vector2i(10, 10))
	var second := make(2, 1, 32, Vector2i(15, 10))
	var third_building := make(3, 2, 1, Vector2i(30, 30), true)
	install([player, second, third_building])
	sim.commands.world._check_end()
	assert(sim.game_end == 0, "R12: 第三参战方仍有建筑时不能结束")
	third_building.alive = false
	third_building.die_t = 0.0
	sim.commands.world._check_end()
	assert(sim.game_end == 1, "R12: 第 3 参战方清空必须获得专属胜利（game_end=%d）" % sim.game_end)
	assert(sim.objective_done, "R12: 专属胜利必须标记 objective_done")
	assert(bool(sim.task_latches.get("29/win", false)), "R12: 专属胜利阶段必须锁存")
	assert(second.alive, "R12: 第 2 方仍存活，证明不是通用歼灭胜利")
	print("SCENARIO 29 PASS third side cleared / second side alive / objective branch latched")
	sim.free()

	# 真实地图：chibic13 参战方依次是 owner 3 / 1 / 2；清空 owner 2 即结束。
	root.get_node("Game").current_map = "chibic13"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true; battle.ai = null
	assert(int(battle.scenario_mission) == 29, "R12: chibic13 应是任务 29")
	var owners: Array = battle.scenario_sides.map(func(s): return int(s.owner))
	assert(owners.size() >= 3 and int(owners[2]) == 2, "R12: chibic13 第 3 参战方应是 owner 2，实际 %s" % str(owners))
	var third := int(owners[2])
	var second_owner := int(owners[1])
	for u in battle.units:
		if int(u.owner) == third:
			u.alive = false; u.die_t = 0.0
	battle.game_end = 0
	battle.objective_done = false
	battle.task_latches.clear()
	battle.commands.world._check_end()
	assert(battle.game_end == 1 and battle.objective_done, "R12: chibic13 清空第三参战方应专属胜利")
	assert(battle.units.any(func(u): return int(u.owner) == second_owner and bool(u.alive) and float(u.die_t) < 0.0), "R12: 第 2 方应仍存活")
	print("SCENARIO 29 MAP PASS chibic13 third side=%d cleared while side %d remains" % [third, second_owner])
	battle.free()
	done = true
	await process_frame
	quit(0)
