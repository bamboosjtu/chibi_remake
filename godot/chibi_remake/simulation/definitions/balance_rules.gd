extends RefCounted
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
static func army_cap() -> int:
	return int(Catalog.get_catalog("balance.json").armyCap)
static func commander_cap() -> int:
	return int(Catalog.get_catalog("balance.json").commanderCap)
static func team_max_members() -> int:
	return int(Catalog.get_catalog("balance.json").teamMaxMembers)
static func transport_capacity() -> int:
	return int(Catalog.get_catalog("balance.json").transportCapacity)


static func harvest() -> Dictionary:
	return Catalog.get_catalog("balance.json").harvest

static func work() -> Dictionary:
	return Catalog.get_catalog("balance.json").work

static func abilities() -> Dictionary:
	return Catalog.get_catalog("balance.json").abilities
