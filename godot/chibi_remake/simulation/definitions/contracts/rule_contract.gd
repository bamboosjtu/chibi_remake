extends RefCounted
## Validate consumed gameplay fields before any catalog becomes visible.
const FILES := ["unit_definitions.json", "production_units.json", "buildings.json", "unit_tuning.json", "officers.json", "officer_progression.json", "command_variants.json", "scenario_rules.json", "native_math.json", "tech.json", "unit_roles.json", "balance.json"]
const Constants = preload("res://simulation/definitions/contracts/constant_contract.gd")
const Scenario = preload("res://simulation/scenario/scenario_contract.gd")
const Status = preload("res://simulation/definitions/status_fields.gd")

static func errors(documents: Dictionary) -> Array:
	var result := []
	for name in FILES:
		if not documents.has(name): result.append(name + ": missing catalog")
		elif not valid(name, documents[name]): result.append(name + ": invalid required gameplay fields")
	if result.is_empty() and not Constants.references(documents): result.append("Rule catalogs: invalid unit or officer reference")
	return result

static func valid(name: String, data) -> bool:
	if not data is Dictionary: return false
	match name:
		"tech.json": return Constants.technology(data)
		"unit_roles.json": return Constants.roles(data)
		"balance.json": return Constants.balance(data)
		"unit_definitions.json": return valid_units(data, true)
		"production_units.json", "buildings.json": return valid_units(data)
		"unit_tuning.json": return _tuning(data)
		"officers.json": return _officers(data)
		"officer_progression.json": return _progression(data)
		"command_variants.json": return _commands(data)
		"scenario_rules.json": return Scenario.valid(data)
		"native_math.json":
			var signature = data.get("sourceSignature")
			return signature is String and signature.length() == 64 and signature.is_valid_hex_number(false) and data.get("algorithm") == "dictionary-math-v1"
	return false

static func _tuning(data: Dictionary) -> bool:
	if not whole(data.get("statusTicks"), 1) or data.statusTicks > Status.MAX_TICKS: return false
	return positive(data.get("hasteMoveMultiplier")) and positive(data.get("slowMoveMultiplier")) and whole(data.get("farsightCells"))

static func valid_units(data, canonical := false) -> bool:
	if not data is Dictionary or not data.get("units") is Dictionary or data.units.is_empty(): return false
	for key in data.units:
		var unit = data.units[key]
		if not str(key).is_valid_int() or not unit is Dictionary: return false
		if not text(unit.get("name")) or (canonical and not text(unit.get("category"))): return false
		for field in ["hp", "attack", "attackB", "defence", "defenceB", "vision", "range", "f9", "costStone", "expGain", "moraleGain"]:
			if not nonnegative(unit.get(field)): return false
		if not numbers(unit.get("costs"), 3): return false
		if not positive(unit.get("w")) or not positive(unit.get("h")): return false
		if not unit.get("frames") is Dictionary: return false
		if not whole(unit.frames.get("count"), 1) or not whole(unit.frames.get("cols"), 1): return false
		if not text(unit.get("sheet")): return false
		if not _clips(unit.get("clips")): return false
		if unit.has("constructionFrames") and not numbers(unit.constructionFrames, 4, true): return false
	return true

static func _clips(clips) -> bool:
	if not clips is Dictionary: return false
	for rows in clips.values():
		if not rows is Array or rows.is_empty(): return false
		for row in rows:
			if not row is Array or row.is_empty(): return false
			for frame in row:
				if not whole(frame): return false
	return true

static func _officers(data: Dictionary) -> bool:
	if not data.get("blocks") is Array or data.blocks.size() != 4: return false
	var factions := {}; var indices := {}
	for block in data.blocks:
		if not block is Dictionary or not whole(block.get("faction"), 1, 4) or factions.has(block.faction): return false
		factions[block.faction] = true
		if not block.get("officers") is Array or block.officers.is_empty(): return false
		for officer in block.officers:
			if not officer is Dictionary or not whole(officer.get("index")) or indices.has(officer.index): return false
			indices[officer.index] = true
			if not text(officer.get("name")) or not whole(officer.get("tier"), 1, 4) or not whole(officer.get("level"), 0, 9): return false
			if not whole(officer.get("heroType")): return false
			for field in ["might", "intellect", "hp"]:
				if not nonnegative(officer.get(field)): return false
	return true

static func _progression(data: Dictionary) -> bool:
	if data.get("levelCap") != 9 or not numbers(data.get("thresholds"), 10): return false
	var previous := 0.0
	for threshold in data.thresholds:
		if float(threshold) <= previous: return false
		previous = float(threshold)
	if not data.get("gradeTable") is Array or data.gradeTable.size() != 10: return false
	for level in range(10):
		var row = data.gradeTable[level]
		if not row is Dictionary or row.get("level") != level or not row.get("cells") is Array or row.cells.size() != 4: return false
		for category in range(4):
			var cell = row.cells[category]
			if not cell is Dictionary or cell.get("category") != category + 1 or not whole(cell.get("grade")) or not text(cell.get("rank")): return false
	if not data.get("rewards") is Array or data.rewards.is_empty(): return false
	for reward in data.rewards:
		# Rewards retain their source order; reward() deliberately selects the first match.
		if not reward is Dictionary or not whole(reward.get("id")): return false
		if not nonnegative(reward.get("killXp")) or not nonnegative(reward.get("morale")): return false
	return true

static func _commands(data: Dictionary) -> bool:
	var model = data.get("three_layer_model")
	if not model is Dictionary: return false
	for group in ["leader", "member", "ungrouped", "transport"]:
		if not model.get(group) is Dictionary: return false
		var fields := ["worker", "combat"] if group in ["leader", "member"] else ["commands"]
		if group == "leader": fields.append("workerVariant")
		for field in fields:
			if not model[group].get(field) is Array or model[group][field].is_empty(): return false
			for command in model[group][field]:
				if not whole(command, 16130, 16145): return false
	return true

static func text(value) -> bool:
	return value is String and not value.is_empty()

static func nonnegative(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

static func positive(value) -> bool:
	return nonnegative(value) and float(value) > 0

static func whole(value, minimum := 0, maximum := 2147483647) -> bool:
	return nonnegative(value) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func numbers(value, count: int, integers := false) -> bool:
	if not value is Array or value.size() != count: return false
	for item in value:
		if not nonnegative(item) or (integers and not whole(item)): return false
	return true
