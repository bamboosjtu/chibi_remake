extends SceneTree
## 回归：早期关卡只有大本营（帅帐）时，工人队点木材必须完成“去资源点→装货→回大本营→入库”的往返。
## 覆盖用户实机反馈：选中武将率领的工人队、点资源后工人不搬货。
var finished := false

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not finished: quit(1))
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game")
	game.current_map = "chibic1"
	var b: Node2D = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var commander: Dictionary = {}
	for u in b.units:
		if u.owner == b.player_owner and b.commands.military._construction_workers(u).size() > 0:
			commander = u
			break
	assert(not commander.is_empty(), "chibic1 应有武将率领的工人队")
	b.selected.clear()
	b.commands.orders._select_click(Vector2(commander.ax, commander.ay - commander.h * 0.5), false)
	var workers: Array = b.commands.economy._selected_workers()
	assert(workers.size() == 4, "点选武将应展开四名工人")
	var origin := Vector2(commander.ax, commander.ay)
	var trees: Array = b.decor_targets.filter(func(o): return bool(o.get("alive", false)) and int(o.get("unit", -1)) == 100)
	assert(not trees.is_empty(), "chibic1 应有可采木材")
	trees.sort_custom(func(a, c): return origin.distance_squared_to(Vector2(a.ax, a.ay)) < origin.distance_squared_to(Vector2(c.ax, c.ay)))
	var tree: Dictionary = trees[0]
	var click := Vector2(float(tree.ax), float(tree.ay) - minf(20.0, float(tree.h) * 0.5))
	assert(not b.commands.economy._resource_at(click).is_empty(), "点击位置应命中木材")
	b.commands.orders._order_context(click)
	var clicked_patch := {}
	for cell in b.commands.orders._resource_patch_cells(tree): clicked_patch[cell] = true
	for worker in workers:
		var assigned_tree: Dictionary = worker.get("gather_obj", {})
		assert(str(worker.state) == "gather" and not assigned_tree.is_empty(), "工人队应接到采集令")
		var assigned_cell: Vector2i = b.nav.cell_of_px(float(assigned_tree.ax), float(assigned_tree.ay))
		assert(clicked_patch.has(assigned_cell), "工人队应在被点击的连通树丛边缘采集")
	var wood0: float = float(b.wood)
	var delivered := false
	for i in range(2700):
		b.commands.world._update_gates()
		for w in workers:
			b.commands.orders._step_unit(w, 1.0 / 30.0)
		if b.wood >= wood0 + 200.0 - 0.01:
			delivered = true
			break
	assert(delivered, "工人应把木材运回大本营并入库（wood 未增加）")
	assert(workers.any(func(w): return float(w.carry) == 0.0), "卸货后应至少有一名工人清空负载")
	print("HQ DELIVERY PASS wood ", wood0, " -> ", b.wood)

	# R02：新建帅帐（CONF-20：3×3=9 格）与读档重建必须得到同一片占格；读档不得把工人包进建筑。
	var placed: Dictionary = {}
	for center in [Vector2(1600, 1600), Vector2(2000, 2200), Vector2(1200, 2400)]:
		placed = b.commands.economy._place_building(b.player_owner, 0, center)
		if not placed.is_empty():
			break
	assert(not placed.is_empty(), "R02: 应能新建帅帐")
	var hq_uid: int = int(placed.uid)
	var built_cells: Array = b.commands.orders._footprint_cells(placed).duplicate()
	assert(built_cells.size() == 9, "R02: 帅帐应为 3×3=9 格，实际 %d" % built_cells.size())
	assert(b.nav.footprint_outline(built_cells).size() == 4, "CONF-20: 实际占格合并后必须是四边形")
	b.nav.rebuild_buildings(b.units)
	assert(placed.occupied_cells.size() == 9, "R02: rebuild_buildings 必须与新建同格数")
	var payload: Dictionary = b.commands.session._save_extra()
	assert(game.save_game(b.units, b.commands.world._resources(), payload))
	var loaded: Dictionary = game.load_save()
	assert(not loaded.is_empty() and b.saver.apply_snapshot(loaded), "R02: 存档应可恢复")
	var hq: Dictionary = b.units.filter(func(u): return int(u.uid) == hq_uid)[0]
	assert(hq.get("occupied_cells", []).size() == 9, "R02: 读档后帅帐占地必须保持 9 格")
	var cell_set := {}
	for raw in hq.occupied_cells:
		cell_set[raw] = true
	for raw in built_cells:
		assert(cell_set.has(raw), "R02: 读档后的占格集合必须与新建一致")
	for unit in b.units:
		if not bool(unit.get("alive", false)) or bool(unit.get("is_building", false)) or bool(unit.get("attached", false)):
			continue
		for raw in b.commands.orders._footprint_cells(unit):
			assert(not cell_set.has(raw), "R02: 读档后单位不能被包进帅帐 %s" % [raw])
	print("HQ FOOTPRINT PASS new/rebuild/load share 3x3 cells and no unit is embedded")
	b.free()
	finished = true
	quit(0)
