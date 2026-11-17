extends SceneTree
const Identity = preload("res://app/saves/rules_identity.gd")
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var records := {}
	for file in Identity.CATALOG_FIELDS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/"+file))
		records[file] = Identity.catalog_hash(JSON.stringify(Identity.rule_projection(file,data)))
	var expected: String = Identity.fingerprint(records)
	assert(Identity.current() == expected)
	for file in ["minimap_terrain.json","audio_index.json","video_catalog.json","unit_display_layout.json","native_math.json","source-comments","engine-hash"]:
		var changed := records.duplicate(); changed[file]="changed"
		assert(Identity.fingerprint(changed)==expected,"Presentation/tool provenance changed rule identity: "+file)
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/unit_definitions.json"))
	var original: Dictionary = Identity.rule_projection("unit_definitions.json",units)
	units.units["30"].name="UI rename"; units.units["30"].sheet="different.png"
	assert(Identity.rule_projection("unit_definitions.json",units)==original)
	units.units["30"].hp += 1
	assert(Identity.rule_projection("unit_definitions.json",units)!=original)
	for file in Identity.CATALOG_FIELDS:
		var changed := records.duplicate(); changed[file]="changed"
		assert(Identity.fingerprint(changed)!=expected,"Effective input omitted: "+file)
	print("RULES SCOPE PASS presentation and engine excluded / combat data included / exact current identity")
	quit()
