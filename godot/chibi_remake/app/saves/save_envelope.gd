extends RefCounted
## File-level validity, independent of installed rules and any live world.
## SnapshotValidator additionally checks map identity, technology and world references.
const Schema = preload("res://simulation/definitions/unit_schema.gd")
const RESOURCE_KEYS := ["gold", "wood", "food", "stone"]

static func integer(value, minimum := 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= 2147483647

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_header(data: Dictionary) -> bool:
	var version = data.get("v",1)
	if not integer(version,1) or int(version)>8: return false
	var ended = data.get("gameEnd",0)
	if not integer(ended) or float(ended)>2: return false
	return int(version)<4 or integer(data.get("nextUid"))

static func valid_collections(data: Dictionary) -> bool:
	var version = data.get("v", 1)
	if not integer(version, 1) or int(version) > 8: return false
	var complete := int(version) >= 8
	if complete and (not data.has("resources") or not data.has("trainings")): return false
	var resources = data.get("resources", {})
	if not resources is Dictionary: return false
	for key in RESOURCE_KEYS:
		if complete and not resources.has(key): return false
	for value in resources.values():
		if not number(value) or float(value) < 0: return false
	return data.get("trainings", []) is Array

static func valid(data: Dictionary) -> bool:
	var version = data.get("v", 1)
	if not valid_header(data): return false
	if not data.get("map") is String or str(data.map).is_empty(): return false
	if data.has("kind") and data.kind != "save": return false
	if not data.get("units") is Array: return false
	if int(version) < 4 and data.units.is_empty(): return false
	if not valid_collections(data): return false
	if int(version) >= 4:
		if not data.get("simulation") is Dictionary or not integer(data.get("nextUid")): return false
	var seen := {}
	for record in data.units:
		if int(version) <= 2:
			if not record is Array or record.size() < (4 if int(version) == 1 else 10): return false
			for index in ([1, 2, 3] if int(version) == 1 else [0, 2, 3, 4, 5, 6]):
				if not number(record[index]): return false
			continue
		if not record is Dictionary or not Schema.valid_record(record): return false
		if not integer(record.get("uid")) or seen.has(int(record.uid)): return false
		seen[int(record.uid)] = true
		for key in ["unit", "owner"]:
			if not integer(record.get(key)): return false
		for key in ["x", "y", "hp"]:
			if not number(record.get(key)): return false
		if int(version) >= 4:
			if not record.get("simulation") is Dictionary: return false
			if not Schema.valid_snapshot(record.simulation): return false
			if not preload("res://simulation/systems/tick_timers.gd").valid_snapshot(record.simulation, int(version)): return false
	return true
