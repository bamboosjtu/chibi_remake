extends RefCounted
## World-local derived values. Never retain source objects in the cache.
const YIELDS = preload("res://simulation/battle_config.gd").RESOURCE_YIELD
const PATCH_LIMIT := 16
const HIT_BUCKET := 64.0
var _key: Array = []
var _patches: Dictionary = {}
var _hits: Dictionary = {}
var _hits_ready := false
var metrics := {"patchBuilds":0,"patchHits":0,"hitBuilds":0,"hitCandidates":0}

func _ensure(data: RefCounted) -> void:
	var key := [data.nav.get_instance_id(), data.nav.state.geometry_revision, data.resource_revision]
	if key == _key: return
	_key = key
	_patches.clear()
	_hits.clear()
	_hits_ready = false

func patch(data: RefCounted, target: Dictionary) -> Dictionary:
	_ensure(data)
	var kind: String = YIELDS.get(int(target.get("unit", -1)), "")
	if not target.get("decor", false) or kind not in ["food", "wood"]: return {}
	var start: Vector2i = data.nav.cell_of_px(float(target.ax), float(target.ay))
	var root := Vector3i(start.x, start.y, 0 if kind == "wood" else 1)
	if _patches.has(root):
		metrics.patchHits += 1
		return _patches[root]
	var cells := _collect(data.decor_cells, start, kind)
	var result := describe(cells)
	# Root-relative BFS order preserves historical tie breaking. Bound the cache
	# instead of storing a full copy for every cell of a thousand-cell forest.
	if _patches.size() >= PATCH_LIMIT: _patches.erase(_patches.keys()[0])
	_patches[root] = result
	metrics.patchBuilds += 1
	return result

func _collect(sources: Dictionary, start: Vector2i, kind: String) -> Array:
	var queue := [start]
	var seen := {start:true}
	var cells := []
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var source: Dictionary = sources.get("%d_%d" % [cell.x, cell.y], {})
		if source.is_empty() or not source.get("alive", false) or YIELDS.get(int(source.unit), "") != kind: continue
		cells.append(cell)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var next := cell + Vector2i(dx, dy)
				if not seen.has(next):
					seen[next] = true
					queue.append(next)
	return cells

func describe(cells: Array) -> Dictionary:
	var mask := {}
	var edges := {}
	for cell in cells: mask[cell] = true
	for cell: Vector2i in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var edge := cell + Vector2i(dx, dy)
				if mask.has(edge): continue
				if not edges.has(edge): edges[edge] = []
				edges[edge].append("%d_%d" % [cell.x, cell.y])
	for sources in edges.values(): sources.make_read_only()
	cells.make_read_only(); mask.make_read_only(); edges.make_read_only()
	var result := {"cells":cells,"mask":mask,"edges":edges}
	result.make_read_only()
	return result

func hit_candidates(data: RefCounted, point: Vector2) -> Array:
	_ensure(data)
	if not _hits_ready:
		for index in range(data.decor_targets.size()):
			var source: Dictionary = data.decor_targets[index]
			var center := Vector2(float(source.ax), float(source.ay) - 30.0)
			var bucket := Vector2i(floori(center.x / HIT_BUCKET), floori(center.y / HIT_BUCKET))
			if not _hits.has(bucket): _hits[bucket] = []
			_hits[bucket].append(index)
		_hits_ready = true
		metrics.hitBuilds += 1
	var result := []
	for x in range(floori((point.x-28.0)/HIT_BUCKET), floori((point.x+28.0)/HIT_BUCKET)+1):
		for y in range(floori((point.y-36.0)/HIT_BUCKET), floori((point.y+36.0)/HIT_BUCKET)+1):
			result.append_array(_hits.get(Vector2i(x,y), []))
	result.sort() # Equal-distance hits retain the original decor array order.
	metrics.hitCandidates += result.size()
	return result
