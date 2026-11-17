extends RefCounted
## Map-dependent admission and documented legacy cleanup windows.
const Schema = preload("res://simulation/definitions/unit_schema.gd")
const MAX_TASK_ENTRIES := 4096
const MAX_TASK_NODES := 32768
const MAX_TASK_DEPTH := 8

static func valid_tasks(simulation: Dictionary) -> bool:
	var latches = simulation.get("taskLatches", {})
	var events = simulation.get("taskEvents", [])
	if not latches is Dictionary or not events is Array: return false
	if latches.size() > MAX_TASK_ENTRIES or events.size() > MAX_TASK_ENTRIES: return false
	for event in events:
		if not event is Dictionary or not _natural(event.get("id")) or not _natural(event.get("tick",0)): return false
	var pending := [[latches,0],[events,0]]
	var nodes := 0
	while not pending.is_empty():
		var entry: Array = pending.pop_back()
		var value = entry[0]
		var depth: int = entry[1]
		nodes += 1
		if nodes > MAX_TASK_NODES or depth > MAX_TASK_DEPTH: return false
		if value is Dictionary:
			if nodes+pending.size()+value.size() > MAX_TASK_NODES: return false
			for key in value:
				if not key is String or key.length() > 256: return false
				pending.append([value[key],depth+1])
		elif value is Array:
			if nodes+pending.size()+value.size() > MAX_TASK_NODES: return false
			for child in value: pending.append([child,depth+1])
		elif value is String:
			if value.length() > 65536: return false
		elif value is float:
			if not is_finite(value): return false
		elif value != null and not value is bool and not value is int: return false
	return true

static func _natural(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= 2147483647

static func valid_rng(value) -> bool:
	if not value is String or value.length() > 20 or not value.is_valid_int() or value.begins_with("+"): return false
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.length() > 19: return false
	if digits.length() == 19 and digits > ("9223372036854775808" if negative else "9223372036854775807"): return false
	return true

static func valid_control(simulation: Dictionary) -> bool:
	if simulation.has("autoControl") and not simulation.autoControl is bool: return false
	if simulation.has("rngState") and not valid_rng(simulation.rngState): return false
	return not simulation.has("tick") or _natural(simulation.tick)

static func valid_timing(simulation: Dictionary) -> bool:
	var speed = simulation.get("speedIndex",2)
	var accumulator = simulation.get("accumulator",0)
	if not _natural(speed) or float(speed)>3: return false
	return (accumulator is int or accumulator is float) and is_finite(float(accumulator)) and float(accumulator)>=0

static func bounds(map: Dictionary) -> Vector2:
	return Vector2(float(map.get("terrainW",0)), float(map.get("terrainH",0)))

static func valid_point(point, map: Dictionary) -> bool:
	if not Schema._point(point): return false
	# Historical edge clicks may sit just outside the canvas. One tile is the
	# admitted cleanup margin, not unbounded coordinates or a navigable region.
	var size := bounds(map)
	var margin := float(map.get("tileW",44))
	return float(point[0]) >= -margin and float(point[1]) >= -margin and float(point[0]) <= size.x+margin and float(point[1]) <= size.y+margin

static func clamp_point(point: Vector2, map: Dictionary) -> Vector2:
	var size := bounds(map)
	return Vector2(clampf(point.x,0,maxf(0,size.x-0.001)),clampf(point.y,0,maxf(0,size.y-0.001)))

static func valid_unit(record: Dictionary, map: Dictionary) -> bool:
	if not valid_point([record.get("x"),record.get("y")],map): return false
	var state: Dictionary = record.simulation
	for field in ["A","B","pi"]:
		if state.get(field) != null and not Schema.valid_value(field,state[field]): return false
	if state.get("pi") != null and float(state.pi) < 0: return false
	var path = state.get("path",[])
	if not path is Array or path.size() > int(map.rows)*int(map.cols)+2: return false
	for point in path:
		if not valid_point(point,map): return false
	var entry := [state.get("site_entry_x",0),state.get("site_entry_y",0)]
	for index in range(2):
		if entry[index] == null: entry[index] = 0
	if not valid_point(entry,map): return false
	var resource = state.get("gatherRef",{})
	if resource is Dictionary and resource.get("kind","")=="spent" and not valid_point([resource.get("x"),resource.get("y")],map): return false
	return not state.has("repathTo") or valid_point(state.repathTo,map)

static func valid_legacy(records: Array, version: int, map: Dictionary) -> bool:
	for record in records:
		if version >= 3:
			if not record is Dictionary or not valid_point([record.get("x"),record.get("y")],map): return false
		else:
			var first := 1 if version == 1 else 2
			if not record is Array or record.size() <= first+1 or not valid_point([record[first],record[first+1]],map): return false
	return true
