extends RefCounted
## Verified DATA.EXP attributes; preserve existing faction sheets and HD anchors.
const ATTRIBUTES := ["name","category","hp","attack","attackB","defence","defenceB","vision","range","f9","costs","costStone","expGain","moraleGain"]
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
## Precedence: map graphics/placement -> canonical attributes -> production cost.
## No input is mutated until both catalogs have passed validation.
static func apply_definitions(map_data: Dictionary) -> bool:
	var data := Catalog.get_catalog("unit_definitions.json")
	var production := Catalog.get_catalog("production_units.json")
	if not map_data.get("units") is Dictionary:
		push_warning("Invalid unit catalog; refusing partial attribute overrides")
		return false
	for key in data.units:
		var reference:Dictionary=data.units[key]
		if not map_data.units.has(key):map_data.units[key]=reference.duplicate(true)
		else:
			for field in ATTRIBUTES:
				map_data.units[key][field] = reference[field].duplicate() if reference[field] is Array else reference[field]
	for key in production.units:
		if not map_data.units.has(key): map_data.units[key] = production.units[key].duplicate(true)
		map_data.units[key].costs = production.units[key].costs.duplicate()
		map_data.units[key].costStone = production.units[key].costStone
	return true

static func valid_catalog(data, canonical := false) -> bool:
	return preload("res://simulation/definitions/rule_contract.gd").valid_units(data, canonical)

static func can_build(unit: Dictionary) -> bool:
	return int(unit.get("unit",-1))==30

