extends RefCounted
## Movement owns replacement of a unit's path. Callers control the existing cursor semantics.
static func set_points(unit: Dictionary, points: Array) -> void:
	unit.path = points
