extends RefCounted
## Structure and cross-reference checks for formerly compiled rule constants.
const ROLE_GROUPS := ["workers", "heroes", "naval", "transports", "officers", "meleeTechnology", "navalTechnology", "mobileHpTechnology", "channelBAttack"]
static func whole(value, minimum := 0, maximum := 2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value)) and value >= minimum and value <= maximum

static func id_list(value, unique := true) -> bool:
	if not value is Array or value.is_empty(): return false
	var seen := {}
	for id in value:
		if not whole(id) or (unique and seen.has(int(id))): return false
		seen[int(id)] = true
	return true

static func technology(data: Dictionary) -> bool:
	if not data.get("rows") is Array or data.rows.size() != 23 or not whole(data.get("researchTicks"), 1): return false
	if not data.get("limits") is Dictionary or data.limits.keys().size() != 7: return false
	for key in ["level", "bow", "weapon", "armor", "catapult", "ship_atk", "ship_def"]:
		if not whole(data.limits.get(key), 1): return false
	var attained := {}
	for row in data.rows:
		if not row is Dictionary or not row.get("name") is String or row.name.is_empty(): return false
		if not row.get("v") is Array or row.v.size() != 8 or not row.get("completion") is Dictionary: return false
		for value in row.v:
			if not whole(value): return false
		if row.has("sell"):
			if not row.sell in ["wood", "stone", "food"] or not row.completion.is_empty(): return false
		elif row.completion.size() != 1: return false
		for key in row.completion:
			if not data.limits.has(key) or not whole(row.completion[key], 1, int(data.limits[key])): return false
			var level := int(row.completion[key])
			if level != int(attained.get(key, 0)) + 1: return false
			attained[key] = level
	if attained.size() != data.limits.size(): return false
	for key in data.limits:
		if int(attained.get(key, 0)) != int(data.limits[key]): return false
	# The existing HP rule applies a uniform increment per HQ level.
	for index in range(int(data.limits.level)):
		if index >= data.rows.size() or data.rows[index].v[4] != data.rows[0].v[4]: return false
	return _technology_lines(data)

static func _technology_lines(data: Dictionary) -> bool:
	if not data.get("lines") is Dictionary or not data.get("buildingLines") is Dictionary: return false
	if data.lines.size() != 7: return false
	for name in ["hq", "bow", "weapon", "armor", "sell", "catapult", "ship"]:
		if not data.lines.has(name): return false
	var seen := {}
	for line in data.lines:
		if not line is String or line.is_empty() or not id_list(data.lines[line]): return false
		for id in data.lines[line]:
			if int(id) >= data.rows.size() or seen.has(int(id)): return false
			var row: Dictionary = data.rows[int(id)]
			if line != "sell" and row.completion.is_empty(): return false
			if line == "sell":
				if not row.has("sell"): return false
			elif line == "ship":
				if not row.completion.keys()[0] in ["ship_atk", "ship_def"]: return false
			elif not row.completion.has("level" if line == "hq" else line): return false
			seen[int(id)] = true
	if seen.size() != data.rows.size(): return false
	for building in data.buildingLines:
		if not str(building).is_valid_int() or not data.buildingLines[building] is Array or data.buildingLines[building].is_empty(): return false
		for line in data.buildingLines[building]:
			if not data.lines.has(line): return false
	return not data.buildingLines.is_empty()

static func roles(data: Dictionary) -> bool:
	for name in ROLE_GROUPS:
		if not id_list(data.get(name)): return false
	if data.transports.size() != 1 or not data.get("technologyCategories") is Array or data.technologyCategories.size() != 4: return false
	var categories := {}
	for group in data.technologyCategories:
		if not id_list(group): return false
		for id in group:
			if categories.has(int(id)): return false
			categories[int(id)] = true
	for id in data.transports:
		if not data.naval.has(id): return false
	for id in data.officers:
		if not data.heroes.has(id): return false
	for id in data.navalTechnology:
		if not data.naval.has(id) or data.transports.has(id): return false
	return true

static func balance(data: Dictionary) -> bool:
	for field in ["armyCap", "commanderCap", "teamMaxMembers", "transportCapacity"]:
		if not whole(data.get(field), 1): return false
	if data.commanderCap > data.armyCap or data.teamMaxMembers > data.armyCap: return false
	for group in ["harvest", "work", "abilities"]:
		if not data.get(group) is Dictionary: return false
	var harvest: Dictionary = data.harvest
	if not whole(harvest.get("periodTicks"), 1) or not whole(harvest.get("pollTicks"), 1): return false
	if harvest.pollTicks > harvest.periodTicks: return false
	if not _positive(harvest.get("carryCapacity")) or not _positive(harvest.get("extractAmount")): return false
	if harvest.extractAmount > harvest.carryCapacity: return false
	if not harvest.get("deposits") is Dictionary or harvest.deposits.size() != 4: return false
	for resource in ["gold", "wood", "food", "stone"]:
		if not id_list(harvest.deposits.get(resource)): return false
	var work: Dictionary = data.work
	if not whole(work.get("restTicks"), 1) or not whole(work.get("buildTicks"), 1): return false
	for field in ["restHp", "repairHp", "buildHp"]:
		if not _positive(work.get(field)): return false
	var cost = work.get("repairCost")
	if not preload("res://simulation/definitions/resource_cost.gd").valid(cost) or cost.size() != 4: return false
	var abilities: Dictionary = data.abilities
	if not _positive(abilities.get("rangeCells")): return false
	if not abilities.get("cost") is Array or abilities.cost.size() != 9: return false
	return abilities.cost.all(func(value): return whole(value))

static func _positive(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0.0

static func references(documents: Dictionary) -> bool:
	var known := {}
	for name in ["unit_definitions.json", "production_units.json", "buildings.json"]:
		for key in documents[name].units: known[int(key)] = true
	var roles: Dictionary = documents["unit_roles.json"]
	for name in ROLE_GROUPS + ["technologyCategories"]:
		var groups: Array = roles[name] if name == "technologyCategories" else [roles[name]]
		for group in groups:
			for id in group:
				if not known.has(int(id)): return false
	for block in documents["officers.json"].blocks:
		for officer in block.officers:
			if not roles.officers.any(func(id): return int(id) == int(officer.heroType)): return false
	for key in documents["tech.json"].buildingLines:
		if not known.has(int(key)): return false
	for row in documents["balance.json"].harvest.deposits.values():
		for id in row:
			if not known.has(int(id)): return false
	return true
