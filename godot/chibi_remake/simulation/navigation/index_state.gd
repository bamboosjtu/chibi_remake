extends RefCounted
## Derived occupancy and index cache writes.

static func set_index_units_size(battle: Object, value: Variant) -> void:
	battle._index_units_size = value

static func set_occupied_cells(unit: Dictionary, value: Variant) -> void:
	unit.occupied_cells = value

static func erase_from_foot_cache(battle: Object, value: Variant) -> void:
	battle._foot_cache.erase(value)
