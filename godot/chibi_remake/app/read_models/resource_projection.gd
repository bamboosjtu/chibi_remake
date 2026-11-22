extends RefCounted
## Spatial buckets contain values and are rebuilt only after geometry or decor changes.
const BUCKET_PIXELS := 256.0
var _key: Array = []
var _buckets := {}

func visible(data: Object, viewport: Rect2) -> Array:
	var key := [data.world.get_instance_id(), data.nav.get_instance_id(), data.nav.geometry_revision, data.resource_revision]
	if key != _key:
		_build(data)
		_key = key
	var start := _bucket(viewport.position - Vector2(22, 0))
	var end := _bucket(viewport.end + Vector2(22, 60))
	var result := []
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			for row in _buckets.get(Vector2i(x, y), []):
				if viewport.intersects(Rect2(row.anchor - Vector2(22, 60), Vector2(44, 60))):
					result.append(row)
	result.sort_custom(func(left, right): return int(left.index) < int(right.index))
	result.make_read_only()
	return result

func _build(data: Object) -> void:
	_buckets.clear()
	var decor: Array = data.map_data.get("decor", [])
	for index in range(decor.size()):
		var cell: Array = decor[index]
		var a := int(cell[0])
		var b := int(cell[1])
		var anchor: Vector2 = data.nav.anchor_of(a, b)
		var source: Dictionary = data.decor_cells.get("%d_%d" % [a, b], {})
		var bucket := _bucket(anchor)
		if not _buckets.has(bucket): _buckets[bucket] = []
		var row := {"index":index, "anchor":anchor, "phase":int(source.get("phase", cell[2]))}
		row.make_read_only()
		_buckets[bucket].append(row)

func _bucket(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / BUCKET_PIXELS), floori(point.y / BUCKET_PIXELS))
