extends RefCounted
## Scenario rule grammar, independent of files and live worlds.
static func valid(data: Dictionary) -> bool:
	if not data.get("missions") is Dictionary or data.missions.is_empty(): return false
	if not data.get("campaignModes") is Dictionary or not data.get("defaultDefeatMode") in ["economy", "army", "escort", "intercept"]: return false
	for policy in data.campaignModes.values():
		if not policy is Dictionary or not policy.get("mode") in ["economy", "army", "escort", "intercept"]: return false
		if policy.mode == "escort" and not _integer(policy.get("requiredOfficer"), 1): return false
	for id in data.missions:
		if not str(id).is_valid_int() or not data.missions[id] is Dictionary: return false
		if not _stages(data.missions[id].get("stages")): return false
	return true

static func _stages(stages) -> bool:
	if not stages is Array or stages.is_empty(): return false
	var seen := {}
	for stage in stages:
		if not stage is Dictionary or not stage.get("id") is String or stage.id.is_empty() or seen.has(stage.id): return false
		if not _condition(stage.get("condition")): return false
		if not stage.get("requires", []) is Array or not stage.get("effects", []) is Array: return false
		for prerequisite in stage.get("requires", []):
			if not prerequisite is String or not seen.has(prerequisite): return false
		for field in ["win", "lose", "yield"]:
			if stage.has(field) and not stage[field] is bool: return false
		for effect in stage.get("effects", []):
			if not _effect(effect): return false
		seen[stage.id] = true
	return true

static func _condition(value, depth := 0) -> bool:
	if depth > 16 or not value is Dictionary: return false
	if not value.get("side", "player") in ["player", "enemy"]: return false
	match value.get("kind"):
		"all":
			if not value.get("conditions") is Array or value.conditions.is_empty(): return false
			for child in value.conditions:
				if not _condition(child, depth + 1): return false
			return true
		"side_cleared": return _integer(value.get("sideIndex"))
		"officer_in_rect", "unit_in_rect":
			if not _coordinates(value.get("rect"), 4): return false
			return value.rect[0] <= value.rect[1] and value.rect[2] <= value.rect[3] and (value.kind == "unit_in_rect" or _integer(value.get("officer"), 1))
		"officers_near":
			return _integer(value.get("officer"), 1) and _integer(value.get("otherOfficer"), 1) and _integer(value.get("radius"), 1) and value.get("otherSide") in ["player", "enemy"]
		"unit_type_present": return _integer(value.get("unit"))
		"enemy_mobile_present": return true
	return false

static func _effect(value) -> bool:
	if not value is Dictionary: return false
	match value.get("kind"):
		"event": return _integer(value.get("id"))
		"status_delta": return value.get("side") in ["player", "enemy"] and _integer(value.get("amount"), -2147483648)
		"officer_experience":
			return _integer(value.get("officer"), 1) and value.get("side", "player") in ["player", "enemy"] and (_integer(value.get("amount")) or value.get("experienceParameter") is String)
		"clear_tiles":
			if not _integer(value.get("layer")) or not value.get("cells") is Array: return false
			for cell in value.cells:
				if not _coordinates(cell, 2): return false
			return true
		"enemy_order": return _coordinates(value.get("target"), 2) and value.get("experienceParameter") is String
	return false

static func _integer(value, minimum := 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum

static func _coordinates(value, size: int) -> bool:
	if not value is Array or value.size() != size: return false
	for number in value:
		if not _integer(number): return false
	return true
