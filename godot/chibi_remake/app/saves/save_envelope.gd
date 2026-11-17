extends RefCounted
## File-level validity, independent of installed rules and any live world.
## SnapshotValidator additionally checks map identity, technology and world references.
const Schema = preload("res://simulation/definitions/unit_schema.gd")
const RESOURCE_KEYS = preload("res://simulation/definitions/resource_cost.gd").KEYS

static func integer(value, minimum := 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= 2147483647

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_header(data: Dictionary) -> bool:
	var version = data.get("v",1)
	if not integer(version,1) or int(version)>8: return false
	var ended = data.get("gameEnd",0)
	if not integer(ended) or float(ended)>2: return false
	return integer(data.get("nextUid")) if int(version)>=4 or data.has("nextUid") else true

static func flag(value) -> bool:
	return value is bool or ((value is int or value is float) and float(value) in [0.0,1.0])

static func _record_valid(record: Dictionary, version: int) -> bool:
	if version >= 4: return Schema.valid_record(record)
	var typed := record.duplicate()
	for key in ["alive","building","mapObject"]:
		if not typed.has(key): continue
		if not flag(typed[key]): return false
		typed[key] = bool(typed[key])
	return Schema.valid_record(typed)

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
	if not data.get("trainings", []) is Array: return false
	if int(version) >= 4:
		for order in data.get("trainings",[]):
			if not order is Dictionary or not integer(order.get("buildingUid")) or not integer(order.get("unit")): return false
			if order.has("owner") and not integer(order.owner): return false
			if order.has("ticks") and not order.ticks is bool: return false
			if not number(order.get("t",0)) or float(order.get("t",0))<0: return false
			if not preload("res://simulation/definitions/resource_cost.gd").valid(order.get("cost",{})): return false
	return true

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
		if not preload("res://app/saves/snapshot_semantics.gd").valid_tasks(data.simulation): return false
		if not preload("res://app/saves/snapshot_semantics.gd").valid_control(data.simulation) or not preload("res://app/saves/snapshot_semantics.gd").valid_timing(data.simulation): return false
	var seen := {}
	for record in data.units:
		if int(version) <= 2:
			if not record is Array or record.size() < (4 if int(version) == 1 else 10): return false
			if not flag(record[0] if int(version)==1 else record[1]): return false
			for index in ([1, 2, 3] if int(version) == 1 else [0, 2, 3, 4, 5, 6]):
				if not number(record[index]): return false
			if int(version)==2:
				for index in [0,5,6]:
					if not integer(record[index]): return false
				if seen.has(int(record[0])) or not flag(record[8]) or not integer(record[9],-1): return false
				seen[int(record[0])] = true
			continue
		if not record is Dictionary or not _record_valid(record,int(version)): return false
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
