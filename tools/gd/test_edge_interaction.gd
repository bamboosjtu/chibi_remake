extends SceneTree
## 回归：采集/卸货必须发生在目标占格的**相邻边缘**；
## 隔 2 格不能采、不能卸（用户实机反馈的“隔空采集/隔空卸货”）。
var finished := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not finished: quit(1))
	_run.call_deferred()

func _place(b: Node2D, w: Dictionary, cell: Vector2i) -> void:
	var p: Vector2 = b.nav.anchor_of(cell.x, cell.y)
	w.ax = p.x; w.ay = p.y; w.A = cell.x; w.B = cell.y; w.path = []; w.pi = 0

func _far_cell(b: Node2D, origin: Vector2i, radius: int) -> Vector2i:
	for r in range(radius, radius + 2):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var c := Vector2i(origin.x + dx, origin.y + dy)
				if c.x < 0 or c.y < 0 or c.x >= int(b.map_data.rows) or c.y >= int(b.map_data.cols): continue
				if b.nav.is_solid(c): continue
				return c
	return Vector2i(-1, -1)

func _far_from_obj(b: Node2D, o: Dictionary) -> Vector2i:
	var oc: Vector2i = b.nav.cell_of_px(float(o.ax), float(o.ay))
	for r in range(2, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var c := Vector2i(oc.x + dx, oc.y + dy)
				if c.x < 0 or c.y < 0 or c.x >= int(b.map_data.rows) or c.y >= int(b.map_data.cols): continue
				if b.nav.is_solid(c): continue
				var p: Vector2 = b.nav.anchor_of(c.x, c.y)
				if b.commands._edge_cell_distance({"ax": p.x, "ay": p.y}, o) >= 2: return c
	return Vector2i(-1, -1)

func _patch_distance(b: Node2D, point: Dictionary, patch: Dictionary) -> int:
	var closest := 999
	for cell in patch:
		var source: Dictionary = b.decor_cells.get("%d_%d" % [cell.x, cell.y], {})
		if not source.is_empty() and bool(source.get("alive", false)):
			closest = mini(closest, b.commands._edge_cell_distance(point, source))
	return closest

func _far_from_patch(b: Node2D, target: Dictionary, patch: Dictionary) -> Vector2i:
	var origin: Vector2i = b.nav.cell_of_px(float(target.ax), float(target.ay))
	for r in range(2, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var cell := Vector2i(origin.x + dx, origin.y + dy)
				if cell.x < 0 or cell.y < 0 or cell.x >= int(b.map_data.rows) or cell.y >= int(b.map_data.cols): continue
				if b.nav.is_solid(cell): continue
				var point: Vector2 = b.nav.anchor_of(cell.x, cell.y)
				if _patch_distance(b, {"ax": point.x, "ay": point.y}, patch) >= 2: return cell
	return Vector2i(-1, -1)

func _run() -> void:
	var game = root.get_node("Game")
	game.current_map = "chibic1"
	var b: Node2D = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var w: Dictionary = b.units.filter(func(u): return u.alive and int(u.owner) == b.player_owner and int(u.unit) == 30)[0]
	var tree: Dictionary = b.decor_targets.filter(func(o): return bool(o.alive) and int(o.unit) == 100)[0]
	var patch := {}
	for cell in b.commands._resource_patch_cells(tree): patch[cell] = true
	var far := _far_from_patch(b, tree, patch)
	assert(far.x >= 0, "树丛旁应有 2 格外的可走格")
	_place(b, w, far)
	assert(_patch_distance(b, w, patch) >= 2, "测试起点必须离树丛 2 格以上")
	var edge_choice: Dictionary = b.commands._resource_patch_interaction_choice(w, tree)
	assert(not edge_choice.is_empty(), "可达树丛必须提供外缘采集点")
	var edge_tree: Dictionary = edge_choice.object
	w.state = "gather"; w.gather_obj = edge_tree; w.gather_ticks = 99; w.gather_t = 3.3; w.carry = 0.0
	b.commands._step_unit(w, b.SIM_DT)
	b.commands._step_unit(w, b.SIM_DT)
	assert(float(w.carry) == 0.0, "距整片树丛 2 格不能采集")

	var ep: Vector2 = edge_choice.path.back()
	w.ax = ep.x; w.ay = ep.y; w.path = []; w.pi = 0
	assert(not patch.has(b.nav.cell_of_px(ep.x, ep.y)), "外缘点不能进入树丛")
	assert(b.commands._edge_cell_distance(w, edge_tree) == 1, "边缘点必须距资源 1 格")
	w.gather_ticks = 99; w.gather_t = 3.3
	b.commands._step_unit(w, b.SIM_DT)
	assert(float(w.carry) == 200.0, "贴边一格才能采集 200")

	var hq: Dictionary = b.units.filter(func(u): return u.alive and int(u.owner) == b.player_owner and int(u.unit) in [0,1])[0]
	var hfar := _far_from_obj(b, hq)
	assert(hfar.x >= 0, "大本营旁应有 2 格外的可走格")
	_place(b, w, hfar)
	w.carry = 200.0; w.carry_kind = "wood"
	assert(b.commands._edge_cell_distance(w, hq) >= 2, "测试起点必须离大本营 2 格以上")
	assert(not b.commands._deposit_carry(w) and float(w.carry) == 200.0, "隔 2 格不能卸货")

	var hp: Vector2 = b.commands._edge_point(hq, Vector2(w.ax, w.ay), b.DEPOSIT_EDGE_PX)
	w.ax = hp.x; w.ay = hp.y; w.path = []; w.pi = 0
	assert(b.commands._edge_cell_distance(w, hq) == 1, "大本营边缘点必须距 1 格")
	var wood0: float = float(b.wood)
	assert(b.commands._deposit_carry(w) and float(w.carry) == 0.0 and b.wood == wood0 + 200.0, "贴边一格才能卸货")
	print("EDGE INTERACTION PASS 2格拒绝/1格成交")
	b.free()
	finished = true
	quit(0)
