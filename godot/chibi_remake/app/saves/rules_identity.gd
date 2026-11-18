extends RefCounted
## Data rules are fixed for a process. Code-rule changes bump the explicit ABI.
const ABI := "battle-rules-v4"
## Code behavior changes require an ABI review; source/export integrity stays in rules_manifest.
const CATALOG_FIELDS := {
	"unit_definitions.json": ["units"],
	"production_units.json": ["units"],
	"buildings.json": ["units"],
	"unit_tuning.json": ["statusTicks", "hasteMoveMultiplier", "slowMoveMultiplier", "farsightCells"],
	"officers.json": ["blocks"],
	"officer_progression.json": ["thresholds", "levelCap", "gradeTable", "rewards"],
	"command_variants.json": ["three_layer_model"],
	"scenario_rules.json": ["missions", "campaignModes", "defaultDefeatMode"],
	"tech.json": ["rows", "lines", "buildingLines", "researchTicks", "limits"],
	"unit_roles.json": ["workers", "heroes", "naval", "transports", "officers", "meleeTechnology", "navalTechnology", "mobileHpTechnology", "technologyCategories", "channelBAttack"],
	"balance.json": ["armyCap", "commanderCap", "teamMaxMembers", "transportCapacity"],
}
## Frozen comparison values from v9 before tuning moved into balance.json.
const V9_TUNING := {
	"harvest": {"periodTicks":100, "pollTicks":4, "carryCapacity":200, "extractAmount":200,
		"deposits":{"wood":[4,5,0,1], "food":[10,11,0,1], "stone":[2,3,0,1], "gold":[23,0,1]}},
	"work": {"restTicks":10, "restHp":1, "repairHp":16, "buildTicks":4, "buildHp":2,
		"repairCost":{"gold":16, "wood":16, "food":16, "stone":16}},
	"abilities": {"cost":[50,100,100,100,200,100,100,10,100], "rangeCells":10},
}
const METADATA := ["name", "heroTypeName", "description", "source", "sourceSha256", "provenance", "sheet", "sheetK", "spriteName", "rank", "message", "message_id", "sound_id"]
static var _current := ""
static func current() -> String:
	if not _current.is_empty(): return _current
	var records := {}
	for name in CATALOG_FIELDS:
		var document := preload("res://simulation/definitions/rule_catalog.gd").get_catalog(name)
		records[name] = catalog_hash(JSON.stringify(rule_projection(name, document)))
	_current = fingerprint(records)
	return _current

static func catalog_hash(text: String) -> String:
	return JSON.stringify(_canonical(JSON.parse_string(text.trim_prefix("\ufeff")))).sha256_text()

static func _canonical(value):
	if value is Dictionary:
		var result := {};var keys: Array=value.keys();keys.sort()
		for key in keys:result[key]=_canonical(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value:result.append(_canonical(item))
		return result
	return value

static func fingerprint(records: Dictionary) -> String:
	var keys := records.keys();keys.sort()
	var ordered := {}
	for key in keys:
		if CATALOG_FIELDS.has(key): ordered[str(key)] = records[key]
	return (ABI+JSON.stringify(ordered)).sha256_text()

static func rule_projection(name: String, data: Dictionary) -> Dictionary:
	var result := {}
	for key in CATALOG_FIELDS.get(name, []): result[key] = _rule_value(data.get(key))
	if name == "balance.json":
		var tuning := {}
		for key in V9_TUNING: tuning[key] = data.get(key)
		if catalog_hash(JSON.stringify(tuning)) != catalog_hash(JSON.stringify(V9_TUNING)):
			result.merge(tuning)
	if name == "unit_roles.json":
		for key in result:
			if key == "technologyCategories":
				for group in result[key]: group.sort()
			else: result[key].sort()
	return result

static func _rule_value(value):
	if value is Dictionary:
		var result := {}
		for key in value:
			if key in METADATA: continue
			if key == "frames": continue # Atlas layout is presentation-only.
			if key == "clips":
				var lengths := {}
				for clip in value.clips:
					lengths[clip] = value.clips[clip].map(func(row): return row.size())
				result.clips = lengths # Action and death cadence depend on length, not frame pixels.
			elif key == "constructionFrames": continue
			else: result[key] = _rule_value(value[key])
		return result
	if value is Array: return value.map(_rule_value)
	return value
