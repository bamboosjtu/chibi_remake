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
}
const METADATA := ["name", "heroTypeName", "description", "source", "sourceSha256", "provenance", "sheet", "sheetK", "spriteName", "rank", "message", "message_id", "sound_id"]
static var _current := ""
static func current() -> String:
	if not _current.is_empty(): return _current
	var records := {}
	for name in CATALOG_FIELDS:
		records[name] = catalog_hash(JSON.stringify(rule_projection(name, JSON.parse_string(FileAccess.get_file_as_string("res://data/db/" + name)))))
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

static func legacy_scenario_hashes() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/rules_contract.json"))
	return data.get("legacyScenarioHashes",[]) if data is Dictionary else []

## Explicitly reviewed transitions only. Pin both fingerprints so this approval
## cannot silently apply to later balance or scenario changes.
static func approved_migration(previous: String) -> bool:
	var contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/rules_contract.json"))
	if not contract is Dictionary:return false
	var migration=contract.get("migrations",{}).get(previous,{})
	return migration is Dictionary and migration.get("target","")==current() and migration.get("policy","") in ["realtime-navigation-v1", "rules-scope-v1", "bounded-blocked-navigation-v1"]

static func rule_projection(name: String, data: Dictionary) -> Dictionary:
	var result := {}
	for key in CATALOG_FIELDS.get(name, []): result[key] = _rule_value(data.get(key))
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
