extends SceneTree
## 回归：非建筑单位不能叠在同一格；两个单位走向同一终点时，后到者必须停在相邻格。
var finished := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not finished: quit(1))
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game")
	game.current_map = "chibic1"
	var b: Node2D = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var workers: Array = b.units.filter(func(u): return u.alive and not u.is_building and int(u.owner) == b.player_owner and int(u.unit) == 30).slice(0, 2)
	assert(workers.size() == 2, "需要两名工人")
	var w1: Dictionary = workers[0]
	var w2: Dictionary = workers[1]
	var start1: Vector2i = b.commands.world._free_unit_cell(b.commands.world._unit_cell(w1), 0, int(w1.uid))
	var a1: Vector2 = b.nav.anchor_of(start1.x, start1.y)
	w1.ax = a1.x; w1.ay = a1.y; w1.A = start1.x; w1.B = start1.y; w1.path = []; w1.pi = 0
	var start2: Vector2i = b.commands.world._free_unit_cell(b.commands.world._unit_cell(w2), 0, int(w2.uid))
	assert(start1.x >= 0 and start2.x >= 0 and start1 != start2)
	var a2: Vector2 = b.nav.anchor_of(start2.x, start2.y)
	w2.ax = a2.x; w2.ay = a2.y; w2.A = start2.x; w2.B = start2.y; w2.path = []; w2.pi = 0
	var dest: Vector2i = b.commands.world._free_unit_cell(Vector2i(int(w1.A) + 5, int(w1.B) + 3), 0, -1)
	assert(dest.x >= 0, "需要共同终点")
	var dp: Vector2 = b.nav.anchor_of(dest.x, dest.y)
	w1.state = "move"; w1.path = b.commands.orders._path_to(w1, dp, true); w1.pi = 0
	w2.state = "move"; w2.path = b.commands.orders._path_to(w2, dp, true); w2.pi = 0
	for i in range(240):
		b.commands.orders._step_unit(w1, b.SIM_DT)
		b.commands.orders._step_unit(w2, b.SIM_DT)
	var c1: Vector2i = b.commands.world._unit_cell(w1)
	var c2: Vector2i = b.commands.world._unit_cell(w2)
	assert(c1 != c2, "两个单位不能叠在同一格: %s" % [c1])
	print("UNIT COLLISION PASS cells=", c1, " ", c2)

	# 新生产单位落在已被占用的格时，必须自动换到最近空格。
	var p: Vector2 = b.nav.anchor_of(c1.x, c1.y)
	var before: int = int(b.units.size())
	assert(b.commands.world._spawn_unit(30, b.player_owner, p.x, p.y, false))
	assert(b.units.size() == before + 1)
	var fresh: Dictionary = b.units.back()
	assert(b.commands.world._unit_cell(fresh) != c1, "新单位不能叠在已占用格")
	print("UNIT SPAWN PASS cell=", b.commands.world._unit_cell(fresh))
	b.free()
	finished = true
	quit(0)
