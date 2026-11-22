extends Object
const CombatState = preload("res://simulation/combat/combat_state.gd")
const CommandState = preload("res://simulation/commands/command_state.gd")
const UnitPath = preload("res://simulation/movement/unit_path.gd")
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _economy: RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## harvest orders: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
var battle: State
var _dep_command_groups: Object
var _dep_interaction_paths: Object
var _dep_spatial_index: Object
var _dep_technology: Object
var resource_index := preload("res://simulation/economy/resource_index.gd").new()

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
	_nav.set_resources(battle.decor_targets)

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

func _selected_workers(actors = null, owner := -1) -> Array:
	var selected: Array = battle.selected if actors == null else actors
	if owner < 0: owner = battle.player_owner
	var result: Array = []
	var leaders := {}
	for u in selected:
		if int(u.get("owner", -1)) != owner: continue
		var oi := int(u.get("officer", {}).get("index", -1))
		if oi >= 0: leaders[oi] = true
	for u in battle.units:
		if not u.alive or u.die_t >= 0.0 or u.is_building or u.owner != owner or bool(u.get("attached", false)): continue
		if _dep_technology._is_harvester_unit(u) and (u in selected or leaders.has(int(u.get("group_officer", -1)))):
			result.append(u)
	return result

func _order_gather_nearest() -> int:
	var count := 0
	var reserved := {}
	for worker in _selected_workers():
		if worker.alive and worker.die_t < 0.0 and _dep_technology._is_harvester_unit(worker):
			var candidate: Dictionary = _reachable_resource_for(worker, reserved)
			if not candidate.is_empty():
				var path: Array = candidate.path
				if not path.is_empty():
					reserved[_nav.cell_of_px(path[path.size() - 1].x, path[path.size() - 1].y)] = true
				_begin_gather(worker, candidate.object, path)
				count += 1
	_effects.feedback("已派出 %d 名工人采集" % count if count > 0 else "没有可达的资源点")
	return count

func _begin_gather(worker: Dictionary, obj: Dictionary, path: Array) -> void:
	_dep_command_groups._cancel_unit_command(worker)
	worker.state = "deliver" if float(worker.carry) > 0.0 else "gather"
	worker.gather_obj = obj
	CommandState.set_hold(worker, false)
	worker.gather_t = 0.0
	worker.gather_ticks = 0
	UnitPath.set_points(worker, path if worker.state == "gather" else [])
	UnitPath.reset_cursor(worker)
	CombatState.set_target(worker, null)

func _order_gather(target_obj: Dictionary, actors = null, owner := -1) -> int:
	if owner < 0: owner = battle.player_owner
	if not target_obj.get("alive", false) or _yield_of(int(target_obj.get("unit", -1))) == "": return 0
	if int(target_obj.unit) in [10,11] and int(target_obj.owner) == owner:
		_effects.feedback("己方粮仓是交付点")
		return 0
	var count := 0
	var reserved := {}
	for worker in _selected_workers(actors, owner):
		if not worker.alive or worker.die_t >= 0.0 or not _dep_technology._is_harvester_unit(worker): continue
		var choice: Dictionary = _harvest_interaction_choice(worker, target_obj, reserved)
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
		reserved[_nav.cell_of_px(path[path.size() - 1].x, path[path.size() - 1].y)] = true
		_begin_gather(worker, obj, path)
		count += 1
	_effects.feedback("已派出 %d 名工人采集" % count if count > 0 else "无法到达该资源点")
	return count

func _reachable_resource_for(u: Dictionary, reserved := {}) -> Dictionary:
	var candidates: Array = (battle.units + battle.decor_targets).filter(
		func(obj): return _can_harvest(u, obj, ""))
	var origin := Vector2(u.ax, u.ay)
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(Vector2(a.ax, a.ay)) < origin.distance_squared_to(Vector2(b.ax, b.ay)))
	var checked_patches := {}
	for obj in candidates:
		var choice := _unchecked_harvest_choice(u, obj, reserved, checked_patches)
		if not choice.is_empty(): return choice
	return {}

func _can_harvest(worker: Dictionary, target: Dictionary, kind: String) -> bool:
	if not bool(target.get("alive", false)) or float(target.get("die_t", -1)) >= 0.0 or bool(target.get("site", false)):
		return false
	var id := int(target.get("unit", -1))
	var target_kind := _yield_of(id)
	if target_kind.is_empty() or (not kind.is_empty() and target_kind != kind):
		return false
	if id in [10, 11]:
		return int(target.owner) != int(worker.owner) and float(_economy.balance(int(target.owner)).get("food", 0)) > 0.0
	return float(target.get("stock", 0)) > 0.0

func _harvest_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	# Trees and crops are grouped into patches. Return
	# an actual border resource as well as its route, so extraction remains within
	# interaction distance after the worker stops outside the connected patch.
	if bool(o.get("decor", false)) and _yield_of(int(o.get("unit", -1))) in ["food", "wood"]:
		return _resource_patch_interaction_choice(u, o, reserved)
	var path: Array = _dep_interaction_paths._edge_interaction_path(u, o, reserved, max_body)
	return {"object": o, "path": path} if not path.is_empty() else {}

func _resource_patch_cells(target: Dictionary) -> Array:
	return resource_index.patch(battle, _nav, target).get("cells", [])

func _resource_patch_interaction_choice(u: Dictionary, target: Dictionary, reserved := {}) -> Dictionary:
	var patch := resource_index.patch(battle, _nav, target)
	if patch.is_empty() or patch.cells.is_empty(): return {}
	var current: Vector2i = _dep_spatial_index._unit_cell(u)
	var origin := Vector2(float(u.ax), float(u.ay))
	var candidates := _patch_candidates(u, patch.edges)
	var ordered: Array = candidates.keys()
	ordered.sort_custom(func(a, b):
		return origin.distance_squared_to(_nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(_nav.anchor_of(b.x, b.y)))
	ordered = ordered.filter(func(edge): return not reserved.has(edge))
	var points: Array = ordered.map(func(edge): return _nav.anchor_of(edge.x, edge.y))
	var accepts := func(path): return _resource_route_stays_outside(path, patch.mask, current)
	var route: Dictionary = _nav.paths.first_path_avoiding(origin, points, patch.cells, current, _dep_command_groups._nav_layer(u), int(u.owner), int(u.unit), accepts)
	if route.is_empty(): return {}
	var point: Vector2 = points[route.index]
	var sources: Array = candidates[ordered[route.index]]
	sources.sort_custom(func(a, b):
		var ad := point.distance_squared_to(Vector2(float(a.ax), float(a.ay)))
		var bd := point.distance_squared_to(Vector2(float(b.ax), float(b.ay)))
		if not is_equal_approx(ad, bd): return ad < bd
		var ac := _nav.cell_of_px(float(a.ax), float(a.ay))
		var bc := _nav.cell_of_px(float(b.ax), float(b.ay))
		return ac.y < bc.y if ac.y != bc.y else ac.x < bc.x)
	return {"object": sources[0], "path": route.path}

func _patch_candidates(u: Dictionary, edges: Dictionary) -> Dictionary:
	var candidates := {}
	for edge: Vector2i in edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= int(battle.map_data.rows) or edge.y >= int(battle.map_data.cols): continue
		if _nav.is_solid_for_order(edge, int(u.owner), _dep_command_groups._nav_layer(u)) or not _dep_spatial_index._cell_unit(edge, int(u.uid)).is_empty(): continue
		var sources := []
		for key in edges[edge]:
			var source: Dictionary = battle.decor_cells.get(key, {})
			if not source.is_empty() and source.get("alive", false): sources.append(source)
		if not sources.is_empty(): candidates[edge] = sources
	return candidates

func _resource_route_stays_outside(path: Array, patch: Dictionary, start_cell: Vector2i) -> bool:
	if path.is_empty():
		return false
	var previous := Vector2.ZERO
	var first := true
	var step_size := maxf(2.0, minf(float(battle.tile_w), float(battle.tile_hh)) * 0.5)
	for raw in path:
		var point: Vector2 = raw
		if first:
			previous = Vector2(float(point.x), float(point.y))
			first = false
		else:
			var length := previous.distance_to(point)
			var samples := maxi(1, ceili(length / step_size))
			for i in range(1, samples + 1):
				var sample := previous.lerp(point, float(i) / float(samples))
				var cell := _nav.cell_of_px(sample.x, sample.y)
				if patch.has(cell) and cell != start_cell:
					return false
			previous = point
		var cell_at_point := _nav.cell_of_px(point.x, point.y)
		if patch.has(cell_at_point) and cell_at_point != start_cell:
			return false
	return true

func _clicked_harvest_patch(target: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	if not bool(target.get("decor", false)): return {}
	var kind := _yield_of(int(target.unit))
	var start := _nav.cell_of_px(float(target.ax), float(target.ay))
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
		var choice := _unchecked_harvest_choice(worker, candidate, reserved, checked_patches)
		if not choice.is_empty(): return choice
	return {}

func _unchecked_harvest_choice(worker: Dictionary, target: Dictionary, reserved: Dictionary, checked_patches: Dictionary) -> Dictionary:
	if bool(target.get("decor", false)):
		var cell: Vector2i = _dep_spatial_index._unit_cell(target)
		if checked_patches.has(cell): return {}
		for member in _resource_patch_cells(target): checked_patches[member] = true
	return _harvest_interaction_choice(worker, target, reserved)

func _nearest_harvest_by_path(worker: Dictionary, kind: String, reserved: Dictionary = {}, exclude: Array = [], previous_field: Vector2 = Vector2.INF) -> Dictionary:
	var radius := maxf(0.0, preload("res://simulation/visibility/battle_visibility.gd").effective_vision(worker)) * float(battle.tile_w)
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
		if not _can_harvest(worker, target, kind): continue
		var point := Vector2(float(target.ax), float(target.ay))
		var near_last_field := bool(target.get("decor", false)) and previous_field.distance_to(point) <= radius
		if here.distance_to(point) > radius and not near_last_field: continue
		candidates.append(target)
	candidates.sort_custom(func(a, b):
		var ca := _nav.cell_of_px(float(a.ax), float(a.ay))
		var cb := _nav.cell_of_px(float(b.ax), float(b.ay))
		if ca.y != cb.y: return ca.y < cb.y
		return ca.x < cb.x)
	var best: Dictionary = {}
	var best_length := INF
	var checked_patches := {}
	for target in candidates:
		var choice := _unchecked_harvest_choice(worker, target, reserved, checked_patches)
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
	var ids: Array = Balance.harvest().deposits.get(kind, [])
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
	return _economy.deposit(u)

func _remove_decor(obj: Dictionary) -> void:
	obj["alive"] = false
	obj["stock"] = 0.0
	obj["phase"] = mini(5, int(obj.phase) | 1)
	_nav.clear_resource(_dep_spatial_index._unit_cell(obj))
	battle.resource_revision += 1

func _resource_at(pos: Vector2) -> Dictionary:
	# 饰物（树/粮）：44×60 精灵矩形判定（点树冠也算，比格中心宽容）。
	var best_dec: Dictionary = {}
	var bd_dec := INF
	for index in resource_index.hit_candidates(battle, _nav, pos):
		var o: Dictionary = battle.decor_targets[index]
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

func bind_dependencies(world: Object) -> void:
	_dep_command_groups = world.command_groups
	_dep_interaction_paths = world.interaction_paths
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_economy = world.economy
	_effects = world.effects
	_nav = world.nav
