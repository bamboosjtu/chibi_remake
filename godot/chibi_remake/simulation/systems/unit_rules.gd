extends RefCounted
## Verified DATA.EXP attributes; preserve existing faction sheets and HD anchors.
const ATTRIBUTES := ["name","category","hp","attack","attackB","defence","defenceB","vision","range","f9","costs","costStone","expGain","moraleGain"]
## Precedence: map graphics/placement -> canonical attributes -> production cost.
## No input is mutated until both catalogs have passed validation.
static func apply_definitions(map_data: Dictionary) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/unit_definitions.json"))
	var production = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/production_units.json"))
	if not valid_catalog(data, true) or not valid_catalog(production) or not map_data.get("units") is Dictionary:
		push_warning("Invalid unit catalog; refusing partial attribute overrides")
		return false
	for key in data.units:
		var reference:Dictionary=data.units[key]
		if not map_data.units.has(key):map_data.units[key]=reference.duplicate(true)
		else:
			for field in ATTRIBUTES:map_data.units[key][field]=reference[field]
	for key in production.units:
		if not map_data.units.has(key): map_data.units[key] = production.units[key].duplicate(true)
		map_data.units[key].costs = production.units[key].costs.duplicate()
		map_data.units[key].costStone = production.units[key].costStone
	return true

static func valid_catalog(data, canonical := false) -> bool:
	if not data is Dictionary or not data.get("units") is Dictionary or data.units.is_empty(): return false
	for key in data.units:
		var unit = data.units[key]
		if not str(key).is_valid_int() or not unit is Dictionary: return false
		if not unit.get("name") is String or str(unit.name).is_empty(): return false
		if canonical and (not unit.get("category") is String or str(unit.category).is_empty()): return false
		for field in ["hp","attack","attackB","defence","defenceB","vision","range","f9","costStone","expGain","moraleGain"]:
			if not _nonnegative(unit.get(field)): return false
		if not unit.get("costs") is Array or unit.costs.size() != 3: return false
		for cost in unit.costs:
			if not _nonnegative(cost): return false
		for field in ["w", "h"]:
			if not _nonnegative(unit.get(field)) or float(unit[field]) <= 0: return false
		if not unit.get("frames") is Dictionary: return false
		for field in ["count", "cols"]:
			if not _nonnegative(unit.frames.get(field)) or float(unit.frames[field]) <= 0: return false
		if not unit.get("sheet") is String or str(unit.sheet).is_empty(): return false
	return true

static func _nonnegative(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

static func can_build(unit: Dictionary) -> bool:
	return int(unit.get("unit",-1))==30

