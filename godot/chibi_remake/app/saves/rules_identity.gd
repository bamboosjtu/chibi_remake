extends RefCounted
## Data rules are fixed for a process. Code-rule changes bump the explicit ABI.
const ABI := "battle-rules-v2"
static var _current := ""
static func current() -> String:
	if not _current.is_empty(): return _current
	var names := DirAccess.get_files_at("res://data/db")
	names.sort()
	var records := {}
	for name in names:
		if str(name) in ["rules_manifest.json","rules_contract.json","registry_compatibility.json"]:continue
		if str(name).ends_with(".json"):
			records[str(name)] = catalog_hash(FileAccess.get_file_as_string("res://data/db/"+str(name)))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/rules_manifest.json"))
	for file in manifest.files:
		# Text scripts are accessible in a source checkout. Compiled exports use
		# the build-checked source identities stored in the manifest instead.
		var bytes:=FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else PackedByteArray()
		var text_script: bool=bytes.size()>0 and bytes.slice(0,4).get_string_from_ascii()!="GDSC"
		records[file]=bytes.get_string_from_utf8().trim_prefix("\ufeff").replace("\r\n","\n").sha256_text() if text_script else manifest.files[file]
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
	for key in keys: ordered[str(key)] = records[key]
	return (ABI+str(Engine.get_version_info().get("hash",""))+JSON.stringify(ordered)).sha256_text()

static func legacy_scenario_hashes() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/rules_contract.json"))
	return data.get("legacyScenarioHashes",[]) if data is Dictionary else []

## Explicitly reviewed transitions only. Pin both fingerprints so this approval
## cannot silently apply to later balance or scenario changes.
static func approved_migration(previous: String) -> bool:
	var contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/rules_contract.json"))
	if not contract is Dictionary:return false
	var migration=contract.get("migrations",{}).get(previous,{})
	return migration is Dictionary and migration.get("target","")==current() and migration.get("policy","")=="realtime-navigation-v1"
