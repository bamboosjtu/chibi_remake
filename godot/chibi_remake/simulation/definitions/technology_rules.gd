extends RefCounted
## Stable row IDs and ordering are part of the current simulation contract.
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
static func data() -> Dictionary:
	return Catalog.get_catalog("tech.json")
static func table() -> Array:
	return data().rows
static func lines() -> Dictionary:
	return data().lines
static func building_lines(unit_id: int) -> Array:
	return data().buildingLines.get(str(unit_id), [])
static func ticks() -> int:
	return int(data().researchTicks)
static func limits() -> Dictionary:
	return data().limits
static func hp_per_level() -> float:
	return float(table()[0].v[4])
