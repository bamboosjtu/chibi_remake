extends RefCounted
## Classifications have distinct meanings: naval technology excludes transports.
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
static func ids(role: String) -> Array:
	return Catalog.get_catalog("unit_roles.json")[role]
static func is_worker(unit_id: int) -> bool:
	return ids("workers").has(unit_id)
static func is_hero(unit_id: int) -> bool:
	return ids("heroes").has(unit_id)
static func is_naval(unit_id: int) -> bool:
	return ids("naval").has(unit_id)
static func is_transport(unit_id: int) -> bool:
	return ids("transports").has(unit_id)
static func uses_channel_b(unit_id: int) -> bool:
	return ids("channelBAttack").has(unit_id)
static func transport_id() -> int:
	return int(ids("transports")[0])
static func is_melee_technology(unit_id: int) -> bool:
	return ids("meleeTechnology").has(unit_id)
static func is_naval_technology(unit_id: int) -> bool:
	return ids("navalTechnology").has(unit_id)
static func has_mobile_hp_technology(unit_id: int) -> bool:
	return ids("mobileHpTechnology").has(unit_id)
static func technology_category(unit_id: int) -> int:
	var categories := ids("technologyCategories")
	for index in range(categories.size()):
		if categories[index].has(unit_id): return index
	return -1
