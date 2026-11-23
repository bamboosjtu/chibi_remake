extends RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Status = preload("res://simulation/definitions/status_fields.gd")
## Authoritative unit field policy. Dictionary units remain the runtime model.
const FIELDS := {
	"gate_open": {"type":"bool", "default":false, "persist":false, "derived":true, "group":"derived"},
	"occupied_cells": {"type":"Array", "default":[], "persist":false, "derived":true, "group":"derived"},
	"route_failures": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "min": 0, "max": 3},
	"blocked_n": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "min": 0, "max": 2147483647},
	"blocked_cursor": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "min": 0, "max": 48},
	"last_attacker_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "min": -1, "max": 2147483647},
	"A": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "cell_cache"},
	"B": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "cell_cache"},
	"maxhp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"base_maxhp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"hold": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"cool": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"repath": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"pi": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "min": 0, "max": 2147483647},
	"anim": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"dir": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"moved": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"build_frame": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"status_173": {"type": "int", "default": 70, "persist": true, "derived": false, "group": "scalar"},
	"event_experience": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"attack_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"defence_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"officer_might": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"officer_intellect": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"group_officer": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "min": -1, "max": 116},
	"team_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "scalar", "values": ["", "worker", "combat"]},
	"carry": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"carry_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "scalar"},
	"gather_t": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"gather_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"delivery_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"tech_hp_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"mou": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"formation": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar"},
	"haste_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"slow_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"farsight_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"confused_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"fo_x": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"fo_y": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"site": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"rest_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0},
	"build_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0},
	"action_wait": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "action", "min": 0, "max": 1000},
	"action_phase": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "action", "min": 0, "max": 23},
	"action_started": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "action"},
	"action_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "action", "values": ["", "attack", "repair"]},
	"action_target_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "action", "min": -1, "max": 2147483647},
	"inspired_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"stock": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "optional": true},
	"stock_max": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "optional": true},
	"attached": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"join_target_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "min": -1, "max": 2147483647},
	"aboard_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar"},
	"carry_n": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"carry_hp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"loaded": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"unload_active": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"unload_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar"},
	"site_inside_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar"},
	"site_follow_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar"},
	"site_entry_x": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"site_entry_y": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar"},
	"site_exit_pending": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar"},
	"build_cost": {"type": "Dictionary", "default": {}, "persist": true, "derived": false, "group": "scalar"},
	"rolling_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"rolling_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0, "max": 29},
	"ambush_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": Status.MAX_TICKS},
	"effect_task": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "effect"},
	"effect_tasks": {"type": "Array", "default": [], "persist": true, "derived": false, "group": "effect"},
	"walk_tick": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 2147483647},
	"move_facing": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 7},
	"turn_tick": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 2147483647},
	"move_started": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "locomotion"},
	"move_turning": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "locomotion"},
	"uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "record", "key": "uid", "min": 0, "max": 2147483647},
	"alive": {"type": "bool", "default": true, "persist": true, "derived": false, "group": "record", "key": "alive"},
	"ax": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "x"},
	"ay": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "y"},
	"hp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "hp"},
	"owner": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "record", "key": "owner", "min": 0, "max": 2147483647},
	"unit": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "record", "key": "unit", "min": 0, "max": 2147483647},
	"is_building": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "record", "key": "building"},
	"map_object": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "record", "key": "mapObject"},
	"map_index": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "record", "key": "mapIndex"},
	"die_t": {"type": "float", "default": -1.0, "persist": true, "derived": false, "group": "record", "key": "dieT"},
	"state": {"type": "String", "default": "idle", "persist": true, "derived": false, "group": "record", "key": "state", "values":["idle","attack","move","join","board","boarded","unload","gather","deliver","rest","repair","build","dead"]},
	"officer": {"type": "Dictionary", "default": {}, "persist": true, "derived": false, "group": "record", "key": "officerIndex"},
	"target": {"type": "Dictionary", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "uid", "key": "targetUid"},
	"build_target": {"type": "Dictionary", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "uid", "key": "build_targetUid"},
	"repair_target": {"type": "Dictionary", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "uid", "key": "repair_targetUid"},
	"board_target": {"type": "Dictionary", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "uid", "key": "board_targetUid"},
	"gather_obj": {"type": "Dictionary", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "gather", "key": "gatherRef"},
	"path": {"type": "Array", "default": [], "persist": true, "derived": false, "group": "relation", "codec": "path", "key": "path"},
	"repath_to": {"type": "Vector2", "default": null, "persist": true, "derived": false, "group": "relation", "codec": "point", "key": "repathTo"},
	"atk_range": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"attack": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"attack_b": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"attack_b_bonus": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"base_vision": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"clips": {"type": "Dictionary", "default": {}, "persist": false, "derived": true, "group": "derived"},
	"count": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
	"defence": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"defence_b": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"defence_b_bonus": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"exp_gain": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"frame_sec": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"grid": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
	"h": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
	"k": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"mitig": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"morale_gain": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"name": {"type": "String", "default": "", "persist": false, "derived": true, "group": "derived"},
	"rate": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
	"tail_value": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
	"vision": {"type": "float", "default": 0.0, "persist": false, "derived": true, "group": "derived"},
	"w": {"type": "int", "default": 0, "persist": false, "derived": true, "group": "derived"},
}

static func fields(group: String) -> Array:
	return FIELDS.keys().filter(func(key): return FIELDS[key].group == group)

static var _persisted_scalars: Array = _scalar_fields()
static var _wire_fields: Dictionary = _allowed_fields()

static func _scalar_fields() -> Array:
	var result := FIELDS.keys().filter(func(key): return FIELDS[key].persist and FIELDS[key].group not in ["record","relation"])
	result.make_read_only()
	return result

static func _allowed_fields() -> Dictionary:
	var result := {}
	for key in _persisted_scalars: result[key] = true
	for key in fields("relation"): result[FIELDS[key].key] = true
	result.make_read_only()
	return result

static func persisted_scalars() -> Array:
	return _persisted_scalars

static func snapshot_scalars(unit: Dictionary) -> Dictionary:
	var result := {}
	for key in persisted_scalars():
		if FIELDS[key].get("optional",false) and not unit.has(key): continue
		result[key] = decode(key,unit.get(key,FIELDS[key].default))
	if unit.has("pi"): result.pi = navigation_cursor(unit.get("path",[]),int(unit.pi))
	return result

static func navigation_cursor(path: Array, cursor: int) -> int:
	return cursor if cursor >= 0 and cursor < path.size() else 0

static func navigation_path(path: Array, cursor: int) -> Array:
	return path if cursor >= 0 and cursor < path.size() else []

static func restore_scalars(state: Dictionary, unit: Dictionary, group := "scalar") -> void:
	for key in fields(group):
		if state.has(key): unit[key] = decode(key,state[key])

static func decode(key: String, value):
	match FIELDS[key].type:
		"int": return int(value)
		"float": return float(value)
	return value.duplicate(true) if value is Array or value is Dictionary else value

static func default_value(key: String):
	return decode(key, FIELDS[key].default)

static func valid_value(key: String, value) -> bool:
	var field: Dictionary = FIELDS[key]
	if value == null: return false
	match field.type:
		"int", "float":
			if not (value is int or value is float) or not is_finite(float(value)): return false
			if field.type == "int" and float(value) != floorf(float(value)): return false
			if field.type == "int" and (float(value) < -2147483648.0 or float(value) > 2147483647.0): return false
			if float(value) < float(field.get("min", -INF)) or float(value) > _maximum(key, field): return false
		"bool":
			if not value is bool: return false
		"String":
			if not value is String: return false
		"Array":
			if not value is Array: return false
		"Dictionary":
			if not value is Dictionary: return false
			if key == "build_cost" and not preload("res://simulation/definitions/resource_cost.gd").valid(value): return false
	return not field.has("values") or value in field["values"]

static func _maximum(key: String, field: Dictionary) -> float:
	match key:
		"rest_t": return float(Balance.work().restTicks) - 1.0
		"build_t": return float(Balance.work().buildTicks) - 1.0
	return float(field.get("max", INF))

static func valid_group(state: Dictionary, group: String) -> bool:
	for key in fields(group):
		if state.has(key) and not valid_value(key, state[key]): return false
	return true

static func valid_snapshot(state: Dictionary) -> bool:
	for key in persisted_scalars():
		if not state.has(key):
			if FIELDS[key].get("optional",false): continue
			return false
		if not valid_value(key,state[key]): return false
	for key in state:
		if not _wire_fields.has(key): return false
	for group in ["scalar", "action", "locomotion", "effect"]:
		if not valid_group(state, group): return false
	return valid_relations(state)

static func valid_relations(state: Dictionary) -> bool:
	for name in fields("relation"):
		var field: Dictionary = FIELDS[name]
		var key: String = field.key
		if not state.has(key): continue
		var value = state[key]
		match field.codec:
			"uid":
				if not _reference(value): return false
			"point":
				if not _point(value): return false
			"path":
				if not value is Array: return false
				for point in value:
					if not _point(point): return false
			"gather":
				if not value is Dictionary: return false
				match value.get("kind", ""):
					"decor":
						if not value.get("cell") is String or value.cell.is_empty(): return false
					"unit":
						if not _reference(value.get("uid")) or int(value.uid) < 0: return false
					"spent":
						if not _reference(value.get("unit")) or int(value.unit) not in [10,11,22,24,25] or not _point([value.get("x"),value.get("y")]): return false
					_: return false
	return true

static func _reference(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= -1 and float(value) <= 2147483647

static func _point(value) -> bool:
	if not value is Array or value.size() != 2: return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return Vector2(float(value[0]),float(value[1])).is_finite()

static func omissions(unit: Dictionary) -> Array:
	return unit.keys().filter(func(key): return not FIELDS.has(key))

static func snapshot_record(unit: Dictionary) -> Dictionary:
	var result := {}
	for key in fields("record"):
		var definition: Dictionary = FIELDS[key]
		result[definition.key] = decode(key, unit.get(key, definition.default)) if key != "officer" else int(unit.get("officer", {}).get("index", -1))
	return result

static func record_value(record: Dictionary, field: String, fallback = null):
	return record.get(FIELDS[field].key, fallback)

static func valid_record(record: Dictionary) -> bool:
	for key in fields("record"):
		var alias: String = FIELDS[key].key
		if not record.has(alias): return false
		if key == "officer":
			var value = record[alias]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < -1 or float(value) > 116: return false
		elif not valid_value(key, record[alias]): return false
	var x_key: String = FIELDS.ax.key
	var y_key: String = FIELDS.ay.key
	if record.has(x_key) and record.has(y_key) and not _point([record[x_key],record[y_key]]): return false
	var unit_key: String = FIELDS.unit.key
	var building_key: String = FIELDS.is_building.key
	if record.has(unit_key) and record.has(building_key):
		if bool(record[building_key]) != is_building_type(int(record[unit_key])): return false
	return true

static func is_building_type(unit_id: int) -> bool:
	return unit_id >= 0 and unit_id <= 26
