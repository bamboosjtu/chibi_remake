extends RefCounted
static func copy(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	freeze(result)
	return result
static func freeze(value) -> void:
	if value is Dictionary:
		for child in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: freeze(child)
		value.make_read_only()
