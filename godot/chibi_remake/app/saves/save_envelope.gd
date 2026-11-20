extends RefCounted
## File admission is independent of an installed map and any live world.
const Format = preload("res://app/saves/save_format.gd")
const Schema = preload("res://simulation/units/unit_schema.gd")
const Cost = preload("res://simulation/definitions/resource_cost.gd")
const Semantics = preload("res://app/saves/snapshot_semantics.gd")
const Relations = preload("res://app/saves/unit_relations.gd")
const RESOURCE_KEYS = Cost.KEYS

static func integer(value, minimum := 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<=2147483647

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_header(data: Dictionary) -> bool:
	return integer(data.get("v")) and int(data.v)==Format.VERSION and integer(data.get("nextUid")) and integer(data.get("gameEnd")) and int(data.gameEnd)<=2

static func valid_collections(data: Dictionary) -> bool:
	if not data.get("resources") is Dictionary or not data.get("trainings") is Array: return false
	for key in RESOURCE_KEYS:
		if not number(data.resources.get(key)) or float(data.resources[key])<0: return false
	for key in data.resources:
		if key not in RESOURCE_KEYS: return false
	for order in data.trainings:
		if not order is Dictionary or not integer(order.get("buildingUid")) or not integer(order.get("unit")): return false
		if not integer(order.get("owner")) or not order.get("ticks") is bool or not order.ticks: return false
		if not integer(order.get("t")) or not Cost.valid(order.get("cost")): return false
	return true

static func valid(data: Dictionary) -> bool:
	if not valid_header(data) or data.get("kind")!="save": return false
	if not data.get("map") is String or data.map.is_empty() or not data.get("units") is Array: return false
	if not valid_collections(data) or not data.get("simulation") is Dictionary: return false
	if not known_world_fields(data.simulation): return false
	if not Semantics.valid_tasks(data.simulation) or not Semantics.valid_control(data.simulation) or not Semantics.valid_timing(data.simulation): return false
	var seen := {}
	for record in data.units:
		if not record is Dictionary or not Schema.valid_record(record): return false
		if seen.has(int(record.uid)) or not record.get("simulation") is Dictionary: return false
		seen[int(record.uid)] = true
		if not Schema.valid_snapshot(record.simulation): return false
		if not preload("res://simulation/systems/tick_timers.gd").valid_snapshot(record.simulation): return false
	return true

static func known_world_fields(simulation: Dictionary) -> bool:
	for key in simulation:
		if key not in Format.WORLD_FIELDS: return false
	for key in ["contentRevision","rulesRevision"]:
		if not simulation.get(key) is String or simulation[key].length()!=64: return false
	return true

static func valid_new(data: Dictionary) -> bool:
	if not valid(data): return false
	var world: Dictionary = data.simulation
	for field in Format.WORLD_FIELDS:
		if field != "autoControl" and not world.has(field): return false
	if not world.objectiveDone is bool or not world.explored is String: return false
	if not world.decorResources is Dictionary or not world.officerPool is Dictionary: return false
	for record in data.units:
		if not Relations.required_on_write(record.simulation): return false
	return true
