extends RefCounted
## harvest orders: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/harvest_orders_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _yield_of(unit_id: int) -> String:
	return str(Config.RESOURCE_YIELD.get(int(unit_id), ""))

func _build_decor_targets() -> void:
	battle.decor_targets.clear()
	battle.decor_cells.clear()
	battle.resource_revision += 1
	var list: Array = battle.map_data.get("decor", [])
	for d in list:
		var a := int(d[0])
		var b := int(d[1])
		var phase := int(d[2])
		# 锚点与地图物件同口径：ax = 44a + 22(b&1) + 22，ay = 11b + 22（脚底中心）。
		var obj := {
			"alive": phase in [0,2,4], "decor": true, "phase": phase, "cell": "%d_%d" % [a, b],
			"unit": 100 + phase, "owner": 0, "is_building": false,
			"uid": -100 - battle.decor_targets.size(),
			"w": 44, "h": 60,
			"ax": float(44 * a + 22 * (b & 1) + 22),
			"ay": float(11 * b + 22),
			"die_t": -1.0, "stock": (200.0 if phase in [0,2] else (50000.0 if phase == 4 else 0.0)),
			"stock_max": (200.0 if phase in [0,2] else (50000.0 if phase == 4 else 0.0)),
		}
		battle.decor_targets.append(obj)
		battle.decor_cells["%d_%d" % [a, b]] = obj
	battle.nav.set_resources(battle.decor_targets)

func _nearest_resource(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for o in battle.units:
		if not o.alive or o.die_t >= 0.0:
			continue
		if _yield_of(int(o.unit)) == "":
			continue
		var d := Vector2(float(o.ax), float(o.ay)).distance_to(pos)
		if d < bd:
			bd = d
			best = o
	for o in battle.decor_targets:
		if not o.alive or _yield_of(int(o.unit)) == "": continue
		var d2 := Vector2(float(o.ax), float(o.ay)).distance_to(pos)
		if d2 < bd:
			bd = d2
			best = o
	return best

func _nearest_deposit(owner: int, pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for u in battle.units:
		if not u.is_building or not u.alive or int(u.owner) != owner:
			continue
		var d := Vector2(float(u.ax), float(u.ay)).distance_to(pos)
		if d < bd:
			bd = d
			best = u
	return best

func _selected_workers() -> Array:
	var result: Array = []
	var leaders := {}
	for u in battle.selected:
		if int(u.get("owner", -1)) != battle.player_owner: continue
		var oi := int(u.get("officer", {}).get("index", -1))
		if oi >= 0: leaders[oi] = true
	for u in battle.units:
		if not u.alive or u.die_t >= 0.0 or u.is_building or u.owner != battle.player_owner or bool(u.get("attached", false)): continue
		if ports._is_worker_unit(u) and (u in battle.selected or leaders.has(int(u.get("group_officer", -1)))):
			result.append(u)
	return result

func _order_gather_nearest() -> int:
	var count := 0
	var reserved := {}
	for worker in _selected_workers():
		if worker.alive and worker.die_t < 0.0 and ports._is_worker_unit(worker):
			var candidate := ports._reachable_resource_for(worker, reserved)
			if not candidate.is_empty():
				var path: Array = candidate.path
				if not path.is_empty():
					reserved[battle.nav.cell_of_px(path[path.size() - 1].x, path[path.size() - 1].y)] = true
				_begin_gather(worker, candidate.object, path)
				count += 1
	ports._feedback("已派出 %d 名工人采集" % count if count > 0 else "没有可达的资源点")
	return count

func _begin_gather(worker: Dictionary, obj: Dictionary, path: Array) -> void:
	ports._cancel_unit_command(worker)
	worker.state = "deliver" if float(worker.carry) > 0.0 else "gather"
	worker.gather_obj = obj
	worker.hold = false
	worker.gather_t = 0.0
	worker.gather_ticks = 0
	worker.path = path if worker.state == "gather" else []
	worker.pi = 0
	worker.target = null
	worker["stuck_t"] = 0.0

func _order_gather(target_obj: Dictionary) -> int:
	if not target_obj.get("alive", false) or _yield_of(int(target_obj.get("unit", -1))) == "": return 0
	if int(target_obj.unit) in [10,11] and int(target_obj.owner) == battle.player_owner:
		ports._feedback("己方粮仓是交付点")
		return 0
	var count := 0
	var reserved := {}
	var assigned := {}
	for worker in _selected_workers():
		if not worker.alive or worker.die_t >= 0.0 or not ports._is_worker_unit(worker): continue
		var choice := ports._edge_interaction_choice(worker, target_obj, reserved)
		if choice.is_empty():
			# Explicitly clicking a dense field orders its reachable edge, even when
			# the crew is still far away. Automatic retargeting keeps its vision limit.
			var alternate := _clicked_harvest_patch(target_obj, worker, reserved)
			if alternate.is_empty():
				alternate = _nearest_harvest_by_path(worker, _yield_of(int(target_obj.unit)), reserved, [target_obj])
			if not alternate.is_empty(): choice = alternate
		if choice.is_empty(): continue
		var obj: Dictionary = choice.object
		var path: Array = choice.path
		assigned[int(obj.get("uid", 0))] = true
		reserved[battle.nav.cell_of_px(path[path.size() - 1].x, path[path.size() - 1].y)] = true
		_begin_gather(worker, obj, path)
		count += 1
	ports._feedback("已派出 %d 名工人采集" % count if count > 0 else "无法到达该资源点")
	return count

func _clicked_harvest_patch(target: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	if not bool(target.get("decor", false)): return {}
	var kind := _yield_of(int(target.unit))
	var start := battle.nav.cell_of_px(float(target.ax), float(target.ay))
	var queue: Array = [start]
	var seen := {start:true}
	var candidates: Array = []
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]; cursor += 1
		var source: Dictionary = battle.decor_cells.get("%d_%d" % [cell.x,cell.y], {})
		if source.is_empty() or _yield_of(int(source.unit)) != kind: continue
		if bool(source.get("alive", false)) and not is_same(source, target): candidates.append(source)
		for dx in range(-1,2):
			for dy in range(-1,2):
				var next := cell + Vector2i(dx,dy)
				if not seen.has(next): seen[next] = true; queue.append(next)
	var click := Vector2(float(target.ax),float(target.ay))
	candidates.sort_custom(func(a,b): return click.distance_squared_to(Vector2(a.ax,a.ay)) < click.distance_squared_to(Vector2(b.ax,b.ay)))
	var checked_patches := {}
	for candidate in candidates:
		var cell := ports._unit_cell(candidate)
		if checked_patches.has(cell):continue
		var cells:=ports._resource_patch_cells(candidate)
		for member_cell in cells:checked_patches[member_cell]=true
		var choice := ports._resource_patch_interaction_choice(worker,candidate,reserved,cells)
		if not choice.is_empty(): return choice
	return {}

func _nearest_harvest_by_path(worker: Dictionary, kind: String, reserved: Dictionary = {}, exclude: Array = []) -> Dictionary:
	var radius := maxf(0.0, preload("res://simulation/systems/battle_visibility.gd").effective_vision(worker)) * float(battle.tile_w)
	var here := Vector2(float(worker.ax), float(worker.ay))
	var candidates: Array = []
	var sources: Array = battle.decor_targets.duplicate()
	sources.append_array(battle.units)
	for raw in sources:
		var target: Dictionary = raw
		if target == null: continue
		var skip := false
		for e in exclude:
			if is_same(e, target):
				skip = true
				break
		if skip: continue
		if not bool(target.get("alive", false)) or float(target.get("die_t", -1)) >= 0.0: continue
		var target_kind := _yield_of(int(target.get("unit", -1)))
		if target_kind == "" or (kind != "" and target_kind != kind): continue
		if bool(target.get("site", false)): continue
		if int(target.get("unit", -1)) in [10, 11] and int(target.get("owner", -1)) == int(worker.get("owner", -2)): continue
		if here.distance_to(Vector2(float(target.ax), float(target.ay))) > radius: continue
		candidates.append(target)
	candidates.sort_custom(func(a, b):
		var ca := battle.nav.cell_of_px(float(a.ax), float(a.ay))
		var cb := battle.nav.cell_of_px(float(b.ax), float(b.ay))
		if ca.y != cb.y: return ca.y < cb.y
		return ca.x < cb.x)
	var best: Dictionary = {}
	var best_length := INF
	var checked_patches := {}
	for target in candidates:
		var choice: Dictionary
		if bool(target.get("decor",false)):
			var cell := ports._unit_cell(target)
			if checked_patches.has(cell):continue
			# Every source in one connected field resolves the same border query.
			# Search it once, retaining the original candidate order and path costs.
			var cells:=ports._resource_patch_cells(target)
			for member_cell in cells:checked_patches[member_cell]=true
			choice=ports._resource_patch_interaction_choice(worker,target,reserved,cells)
		else:choice=ports._edge_interaction_choice(worker,target,reserved)
		if choice.is_empty(): continue
		var length := _path_travel_length(worker, choice.path)
		if length < best_length:          # 严格小于 → 同距保留先 y 后 x 的稳定顺序
			best_length = length
			best = choice
	return best

func _path_travel_length(worker: Dictionary, path: Array) -> float:
	var total := 0.0
	var previous := Vector2(float(worker.ax), float(worker.ay))
	for raw in path:
		var point: Vector2 = raw
		total += previous.distance_to(point)
		previous = point
	return total

func _nearby_same_resource(origin_obj: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	var kind := _yield_of(int(origin_obj.get("unit", -1)))
	if kind == "": return {}
	var found := _nearest_harvest_by_path(worker, kind, reserved, [origin_obj])
	return found.get("object", {})

func _deposits_for(u: Dictionary, kind: String) -> Array:
	var ids: Array = Config.DEPOSIT_UNITS.get(kind, [])
	var preferred: Array = []
	for b in battle.units:
		if not bool(b.get("alive", false)) or b.die_t >= 0 or not bool(b.is_building) or int(b.get("owner", -1)) != int(u.get("owner", -1)):
			continue
		if bool(b.get("site", false)):
			continue                       # 工地不收货（还没建成）
		if ids.has(int(b.get("unit", -1))):
			preferred.append(b)
	var here := Vector2(float(u.ax), float(u.ay))
	var by_near := func(a, b): return here.distance_squared_to(Vector2(a.ax, a.ay)) < here.distance_squared_to(Vector2(b.ax, b.ay))
	preferred.sort_custom(by_near)
	return preferred

func _food_capacity(owner: int) -> float:
	var n := 0
	for b in battle.units:
		if bool(b.get("alive", false)) and b.die_t < 0 and bool(b.is_building) and int(b.get("owner", -1)) == owner:
			if Config.FOOD_BUILDINGS.has(int(b.get("unit", -1))) and not bool(b.get("site", false)):
				n += 1
	return float(n) * 10000.0

func _deposit_carry(u: Dictionary) -> bool:
	return battle.economy.deposit(u)

func _remove_decor(obj: Dictionary) -> void:
	obj["alive"] = false
	obj["stock"] = 0.0
	obj["phase"] = mini(5, int(obj.phase) | 1)
	battle.nav.clear_resource(ports._unit_cell(obj))
	battle.resource_revision += 1

func _resource_at(pos: Vector2) -> Dictionary:
	# 饰物（树/粮）：44×60 精灵矩形判定（点树冠也算，比格中心宽容）。
	var best_dec: Dictionary = {}
	var bd_dec := INF
	for o in battle.decor_targets:
		if not o.alive or _yield_of(int(o.unit)) == "": continue
		var ddx := float(o.ax)
		var ddy := float(o.ay) - 30.0
		if absf(pos.x - ddx) <= 28.0 and absf(pos.y - ddy) <= 36.0:
			var dd := pos.distance_to(Vector2(ddx, ddy))
			if dd < bd_dec:
				bd_dec = dd
				best_dec = o
	if not best_dec.is_empty():
		return best_dec
	for u in battle.units:
		if not u.alive or u.die_t >= 0.0:
			continue
		if _yield_of(int(u.unit)) == "":
			continue
		var cx := float(u.ax)
		var cy := float(u.ay) - float(u.h) * 0.5
		if absf(pos.x - cx) <= float(u.w) * 0.5 + 6.0 and absf(pos.y - cy) <= float(u.h) * 0.5 + 6.0:
			return u
	return {}
