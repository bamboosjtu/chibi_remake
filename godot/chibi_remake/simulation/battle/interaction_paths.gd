extends RefCounted
## interaction paths: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/interaction_paths_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _interaction_path(u: Dictionary, obj: Dictionary, reach: float) -> Array:
	if _dist_to_obj(u, obj) <= reach: return [Vector2(u.ax, u.ay)]
	var c := battle.nav.cell_of_px(float(obj.ax), float(obj.ay) - float(obj.h) * 0.25)
	var rx := ceili((float(obj.w) * 0.5 + reach) / battle.tile_w) + 1
	var ry := ceili((float(obj.h) + reach) / battle.tile_hh) + 1
	var candidates: Array = []
	for x in range(maxi(0, c.x - rx), mini(int(battle.map_data.rows), c.x + rx + 1)):
		for y in range(maxi(0, c.y - ry), mini(int(battle.map_data.cols), c.y + ry + 1)):
			var cell := Vector2i(x, y)
			if battle.nav.is_solid(cell): continue
			# 落脚点不能是别的单位（含目标船体）的占格；否则会反复寻到同一个“终点被占”，
			# 例如运输船 4 格占位时，离包围盒最近的格可能正落在船体里。
			if not ports._cell_unit(cell, int(u.get("uid", -1)), -1).is_empty(): continue
			var point := battle.nav.anchor_of(x, y)
			if _dist_to_obj({"ax": point.x, "ay": point.y}, obj) <= reach - 6.0: candidates.append(point)
	var origin := Vector2(u.ax, u.ay)
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(a) < origin.distance_squared_to(b))
	for point in candidates:
		var path := ports._path_to(u, point, true)
		if path.is_empty():
			continue
		# 精确终点可能被吸附/最后一段不通，路径停在半路（例如大船体旁的陆地格）。
		# 只有**路径实际终点**也能进入交互距离时才算成功，否则换下一个候选。
		var last: Vector2 = path[path.size() - 1]
		if _dist_to_obj({"ax": last.x, "ay": last.y}, obj) <= reach:
			return path
	return []

func _reachable_resource_for(u: Dictionary, reserved := {}) -> Dictionary:
	var candidates: Array = []
	for obj in battle.units:
		if obj.alive and obj.die_t < 0.0 and ports._yield_of(int(obj.unit)) != "": candidates.append(obj)
	for obj in battle.decor_targets:
		if obj.alive and ports._yield_of(int(obj.unit)) != "": candidates.append(obj)
	var origin := Vector2(u.ax, u.ay)
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(Vector2(a.ax, a.ay)) < origin.distance_squared_to(Vector2(b.ax, b.ay)))
	for obj in candidates:
		var choice := _edge_interaction_choice(u, obj, reserved)
		if not choice.is_empty(): return choice
	return {}

func _dist_to_obj(u: Dictionary, o: Dictionary) -> float:
	var hw := float(o.w) * 0.5
	var hh := float(o.h) * 0.5
	var cx := float(o.ax)
	var cy := float(o.ay) - hh          # 身体中心
	var dx: float = maxf(0.0, absf(float(u.ax) - cx) - hw)
	var dy: float = maxf(0.0, absf(float(u.ay) - cy) - hh)
	return sqrt(dx * dx + dy * dy)

func _footprint_cells(o: Dictionary) -> Array:
	var occupied: Array = o.get("occupied_cells", [])
	if not occupied.is_empty():
		return occupied
	var c := battle.nav.cell_of_px(float(o.ax), float(o.ay))
	if bool(o.get("decor", false)):
		return [c]
	if not bool(o.get("is_building", false)):
		# CONF-20：士兵/工人/武将/船按兵种占格档取形状（档 0 仍是单格）。
		# R13：按（uid, 锚点格, 兵种）缓存形状，避免每次防叠查询都重建数组。
		var uid := int(o.get("uid", -1))
		var unit_id := int(o.get("unit", -1))
		if uid >= 0:
			var cached: Dictionary = battle._foot_cache.get(uid, {})
			if not cached.is_empty() and cached.anchor == c and int(cached.unit) == unit_id:
				return cached.cells
			var shaped: Array = preload("res://simulation/systems/unit_footprint.gd").shape(unit_id, c)
			battle._foot_cache[uid] = {"anchor": c, "unit": unit_id, "cells": shaped}
			return shaped
		return preload("res://simulation/systems/unit_footprint.gd").shape(unit_id, c)
	var w := float(o.get("w", 44.0))
	# CONF-20 / R02: share the original type's square with placement and load.
	var fp: Array = battle.nav.building_footprint(int(o.get("unit", -1)), Vector2(float(o.ax), float(o.ay)), w)
	return fp if not fp.is_empty() else [c]

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	var uc := battle.nav.cell_of_px(float(u.ax), float(u.ay))
	var best := 0x3fffffff
	for raw in _footprint_cells(o):
		var c: Vector2i = raw
		best = mini(best, maxi(absi(uc.x - c.x), absi(uc.y - c.y)))
	return best

func _deposit_ready(u: Dictionary, o: Dictionary) -> bool:
	return _edge_cell_distance(u, o) == Config.EDGE_DISTANCE and _dist_to_obj(u, o) <= Config.DEPOSIT_EDGE_PX

func _edge_neighbors(o: Dictionary, exclude_uid := -1, require_free := false, owner := -1) -> Array:
	var out: Array = []
	var seen := {}
	var foot := {}
	for raw in _footprint_cells(o):
		foot[raw] = true
	for raw in _footprint_cells(o):
		var c: Vector2i = raw
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= int(battle.map_data.rows) or n.y >= int(battle.map_data.cols): continue
				if foot.has(n) or seen.has(n) or battle.nav.is_solid_for_order(n,owner): continue
				if (exclude_uid >= 0 or require_free) and not ports._cell_unit(n, exclude_uid).is_empty(): continue
				seen[n] = true
				out.append(n)
	return out

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	var choice := _edge_interaction_choice(u, o, reserved, max_body)
	return choice.get("path", [])

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	# Trees and crops form a walkable decorative patch in the source map. Return
	# an actual border resource as well as its route, so extraction remains within
	# interaction distance after the worker stops outside the connected patch.
	if bool(o.get("decor", false)) and ports._yield_of(int(o.get("unit", -1))) in ["food", "wood"]:
		return _resource_patch_interaction_choice(u, o, reserved)
	var path := _edge_interaction_path_core(u, o, reserved, max_body)
	return {"object": o, "path": path} if not path.is_empty() else {}

func _edge_interaction_path_core(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	var ucell := ports._unit_cell(u)
	if _edge_cell_distance(u, o) == Config.EDGE_DISTANCE and not reserved.has(ucell) \
			and (max_body < 0.0 or _dist_to_obj(u, o) <= max_body):
		return [Vector2(u.ax, u.ay)]
	var origin := Vector2(float(u.ax), float(u.ay))
	var candidates := _edge_neighbors(o, int(u.uid), false, int(u.owner))
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(battle.nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(battle.nav.anchor_of(b.x, b.y)))
	for c in candidates:
		if reserved.has(c): continue
		var point := battle.nav.anchor_of(c.x, c.y)
		if max_body >= 0.0 and _dist_to_obj({"ax": point.x, "ay": point.y}, o) > max_body: continue
		var path := ports._path_to(u, point, true)
		if path.is_empty():
			# 森林/资源密集区单位避让会把唯一通道挖空；采集路径退回普通 A*，
			# 最终落点仍由 _follow 的叠格检查与分离逻辑兜底。
			path = battle.nav.find_path(origin, point, true, ports._nav_layer(u), int(u.get("owner", 0)), int(u.get("unit", -1)))
		if not path.is_empty(): return path
	return []

func _resource_patch_cells(target: Dictionary) -> Array:
	if not bool(target.get("decor", false)):
		return []
	var kind := ports._yield_of(int(target.get("unit", -1)))
	if kind not in ["food", "wood"]:
		return []
	var start := battle.nav.cell_of_px(float(target.ax), float(target.ay))
	var queue: Array = [start]
	var seen := {start: true}
	var patch: Array = []
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var source: Dictionary = battle.decor_cells.get("%d_%d" % [cell.x, cell.y], {})
		if source.is_empty() or not bool(source.get("alive", false)) or ports._yield_of(int(source.get("unit", -1))) != kind:
			continue
		patch.append(cell)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var next := cell + Vector2i(dx, dy)
				if not seen.has(next):
					seen[next] = true
					queue.append(next)
	return patch

func _resource_patch_interaction_choice(u: Dictionary, target: Dictionary, reserved := {}, known_cells: Array = []) -> Dictionary:
	var cells := known_cells if not known_cells.is_empty() else _resource_patch_cells(target)
	if cells.is_empty():
		return {}
	var patch := {}
	for raw in cells:
		patch[raw] = true
	var current := ports._unit_cell(u)
	var origin := Vector2(float(u.ax), float(u.ay))
	var candidates := {}
	for raw in cells:
		var cell: Vector2i = raw
		var source: Dictionary = battle.decor_cells.get("%d_%d" % [cell.x, cell.y], {})
		if source.is_empty() or not bool(source.get("alive", false)):
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var edge := cell + Vector2i(dx, dy)
				if patch.has(edge):
					continue
				if edge.x < 0 or edge.y < 0 or edge.x >= int(battle.map_data.rows) or edge.y >= int(battle.map_data.cols):
					continue
				if battle.nav.is_solid_for_order(edge,int(u.owner),ports._nav_layer(u)) or not ports._cell_unit(edge, int(u.uid)).is_empty():
					continue
				if not candidates.has(edge): candidates[edge] = []
				candidates[edge].append(source)
	var ordered: Array = candidates.keys()
	ordered.sort_custom(func(a, b):
		return origin.distance_squared_to(battle.nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(battle.nav.anchor_of(b.x, b.y)))
	var avoid := cells.duplicate()
	# A worker restored from an older save may already be standing inside a patch.
	# Allow its current cell as the path origin so it can step out, while every
	# other cell in the patch stays blocked for this route.
	avoid.erase(current)
	for edge in ordered:
		if reserved.has(edge):
			continue
		var point := battle.nav.anchor_of(edge.x, edge.y)
		var sources: Array = candidates[edge]
		sources.sort_custom(func(a, b):
			var ad := point.distance_squared_to(Vector2(float(a.ax), float(a.ay)))
			var bd := point.distance_squared_to(Vector2(float(b.ax), float(b.ay)))
			if not is_equal_approx(ad, bd): return ad < bd
			var ac := battle.nav.cell_of_px(float(a.ax), float(a.ay))
			var bc := battle.nav.cell_of_px(float(b.ax), float(b.ay))
			return ac.y < bc.y if ac.y != bc.y else ac.x < bc.x)
		var path := battle.nav.find_path_avoiding(origin, point, true, avoid, ports._nav_layer(u), int(u.owner), int(u.unit))
		if path.is_empty() or not _resource_route_stays_outside(path, patch, current):
			continue
		return {"object": sources[0], "path": path}
	return {}

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
				var cell := battle.nav.cell_of_px(sample.x, sample.y)
				if patch.has(cell) and cell != start_cell:
					return false
			previous = point
		var cell_at_point := battle.nav.cell_of_px(point.x, point.y)
		if patch.has(cell_at_point) and cell_at_point != start_cell:
			return false
	return true

func _edge_point(o: Dictionary, from_px := Vector2.ZERO, max_body := -1.0, exclude_uid := -1) -> Vector2:
	var cells := _edge_neighbors(o, exclude_uid, true)
	if cells.is_empty(): return Vector2(float(o.ax), float(o.ay))
	var origin := from_px
	if origin == Vector2.ZERO:
		origin = Vector2(float(o.ax), float(o.ay))
	cells.sort_custom(func(a, b): return origin.distance_squared_to(battle.nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(battle.nav.anchor_of(b.x, b.y)))
	for c in cells:
		var p := battle.nav.anchor_of(c.x, c.y)
		if max_body >= 0.0 and _dist_to_obj({"ax": p.x, "ay": p.y}, o) > max_body: continue
		return p
	return Vector2(float(o.ax), float(o.ay))
