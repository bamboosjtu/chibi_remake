extends RefCounted
## v9 relationship wire values come from the UnitSchema registry.
const Schema = preload("res://simulation/units/unit_schema.gd")
static var _fields := Schema.fields("relation")

static func encode(unit: Dictionary, by_uid: Dictionary) -> Dictionary:
	var result := {}
	for name in _fields:
		var field: Dictionary = Schema.FIELDS[name]
		var value = unit.get(name)
		match field.codec:
			"uid":
				var uid := int(value.get("uid", -1)) if value is Dictionary else -1
				result[field.key] = uid if name == "target" or _is_live_reference(value, by_uid) else -1
			"gather":
				if value is Dictionary and not value.is_empty(): result[field.key] = _gather_ref(value, by_uid)
			"point":
				if value is Vector2: result[field.key] = [value.x, value.y]
			"path":
				result[field.key] = Schema.navigation_path(unit.get(name, []), int(unit.get("pi", 0))).map(
					func(point: Vector2): return [point.x, point.y])
	return result

static func restore(unit: Dictionary, state: Dictionary, by_uid: Dictionary, decor: Dictionary) -> void:
	for name in _fields:
		var field: Dictionary = Schema.FIELDS[name]
		var value = state.get(field.key)
		match field.codec:
			"uid":
				unit[name] = by_uid.get(int(value) if value != null else -1)
			"gather":
				if value is Dictionary: unit[name] = _restore_gather_ref(value, by_uid, decor)
			"point":
				if value is Array: unit[name] = Vector2(float(value[0]), float(value[1]))
			"path":
				unit[name] = (value as Array).map(func(point): return Vector2(float(point[0]), float(point[1])))
				unit.pi = int(state.pi)

static func required_on_write(state: Dictionary) -> bool:
	for name in _fields:
		var field: Dictionary = Schema.FIELDS[name]
		if field.codec in ["uid", "path"] and not state.has(field.key): return false
	return true

static func _is_live_reference(unit, by_uid: Dictionary) -> bool:
	return unit is Dictionary and not unit.is_empty() and is_same(by_uid.get(int(unit.get("uid", -1))), unit)

static func _gather_ref(unit: Dictionary, by_uid: Dictionary) -> Dictionary:
	if bool(unit.get("decor", false)):
		return {"kind":"decor", "cell":str(unit.get("cell", ""))}
	if _is_live_reference(unit, by_uid):
		return {"kind":"unit", "uid":int(unit.uid)}
	# A depleted source can disappear while a worker still carries its resources.
	return {"kind":"spent", "unit":int(unit.unit), "x":float(unit.ax), "y":float(unit.ay)}

static func _restore_gather_ref(value: Dictionary, by_uid: Dictionary, decor: Dictionary):
	match value.get("kind", ""):
		"decor": return decor.get(str(value.cell))
		"unit": return by_uid.get(int(value.uid))
		"spent": return {"unit":int(value.unit), "ax":float(value.x), "ay":float(value.y), "alive":false, "die_t":0.0}
	return null
