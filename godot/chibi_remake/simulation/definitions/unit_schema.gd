extends RefCounted
## Authoritative unit field policy. Dictionary units remain the runtime model.
const Config = preload("res://simulation/battle_config.gd")
const FIELDS := {
	"gate_open": {"type":"bool", "default":false, "persist":false, "derived":true, "group":"derived"},
	"occupied_cells": {"type":"Array", "default":[], "persist":false, "derived":true, "group":"derived"},
	"route_failures": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true, "min": 0, "max": 3},
	"blocked_n": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true, "min": 0, "max": 2147483647},
	"last_attacker_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true, "min": -1, "max": 2147483647},
	"A": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"B": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"maxhp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"base_maxhp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"hold": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"cool": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"repath": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"pi": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"anim": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"dir": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"moved": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"build_frame": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"status_173": {"type": "int", "default": 70, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"event_experience": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"attack_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"defence_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"officer_might": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"officer_intellect": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"group_officer": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true, "min": -1, "max": 116},
	"team_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "scalar", "nullable": true, "values": ["", "worker", "combat"]},
	"carry": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"carry_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"gather_t": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"gather_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"delivery_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"tech_hp_bonus": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"mou": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"formation": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"haste_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"slow_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"farsight_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"confused_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"burn_t": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"burn_dps": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"fo_x": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"fo_y": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"rest_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0, "max": Config.REST_TICKS - 1},
	"build_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0, "max": Config.BUILD_STEP_TICKS - 1},
	"action_wait": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "action", "min": 0, "max": 1000},
	"action_phase": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "action", "min": 0, "max": 23},
	"action_started": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "action"},
	"action_kind": {"type": "String", "default": "", "persist": true, "derived": false, "group": "action", "values": ["", "attack", "repair"]},
	"action_target_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "action", "min": -1, "max": 2147483647},
	"inspired_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"stock": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"stock_max": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"attached": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"join_target_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true, "min": -1, "max": 2147483647},
	"aboard_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"carry_n": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"carry_hp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"loaded": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"unload_active": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"unload_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site_inside_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site_follow_uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site_entry_x": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site_entry_y": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"site_exit_pending": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"build_cost": {"type": "Dictionary", "default": {}, "persist": true, "derived": false, "group": "scalar", "nullable": true},
	"rolling_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"rolling_ticks": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "elapsed", "min": 0, "max": 29},
	"ambush_t": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "status", "min": 0, "max": 800},
	"effect_task": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "effect"},
	"effect_tasks": {"type": "Array", "default": [], "persist": true, "derived": false, "group": "effect"},
	"walk_tick": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 2147483647},
	"move_facing": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 7},
	"turn_tick": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "locomotion", "min": 0, "max": 2147483647},
	"move_started": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "locomotion"},
	"move_turning": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "locomotion"},
	"uid": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "record", "key": "uid"},
	"alive": {"type": "bool", "default": true, "persist": true, "derived": false, "group": "record", "key": "alive"},
	"ax": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "x"},
	"ay": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "y"},
	"hp": {"type": "float", "default": 0.0, "persist": true, "derived": false, "group": "record", "key": "hp"},
	"owner": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "record", "key": "owner"},
	"unit": {"type": "int", "default": 0, "persist": true, "derived": false, "group": "record", "key": "unit"},
	"is_building": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "record", "key": "building"},
	"map_object": {"type": "bool", "default": false, "persist": true, "derived": false, "group": "record", "key": "mapObject"},
	"map_index": {"type": "int", "default": -1, "persist": true, "derived": false, "group": "record", "key": "mapIndex"},
	"die_t": {"type": "float", "default": -1.0, "persist": true, "derived": false, "group": "record", "key": "dieT"},
	"state": {"type": "String", "default": "idle", "persist": true, "derived": false, "group": "record", "key": "state"},
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

static func persisted_scalars() -> Array:
	return FIELDS.keys().filter(func(key): return FIELDS[key].persist and FIELDS[key].group not in ["record", "relation"])

static func snapshot_scalars(unit: Dictionary) -> Dictionary:
	var result := {}
	for key in persisted_scalars():
		if unit.has(key): result[key] = unit[key] if FIELDS[key].type != "int" or unit[key] == null else int(unit[key])
	return result

static func restore_scalars(state: Dictionary, unit: Dictionary, group := "scalar") -> void:
	for key in fields(group):
		var value = state.get(key)
		if value == null: continue # Older v4-v8 writers emitted null for absent optional fields.
		unit[key] = decode(key, value)

static func decode(key: String, value):
	match FIELDS[key].type:
		"int": return int(value)
		"float": return float(value)
	return value.duplicate(true) if value is Array or value is Dictionary else value

static func default_value(key: String):
	return decode(key, FIELDS[key].default)

static func valid_value(key: String, value) -> bool:
	var field: Dictionary = FIELDS[key]
	if value == null: return bool(field.get("nullable", false))
	match field.type:
		"int", "float":
			if not (value is int or value is float) or not is_finite(float(value)): return false
			if field.type == "int" and float(value) != floorf(float(value)): return false
			if float(value) < float(field.get("min", -INF)) or float(value) > float(field.get("max", INF)): return false
		"bool":
			if not value is bool: return false
		"String":
			if not value is String: return false
		"Array":
			if not value is Array: return false
		"Dictionary":
			if not value is Dictionary: return false
	return not field.has("values") or value in field["values"]

static func valid_group(state: Dictionary, group: String) -> bool:
	for key in fields(group):
		if state.has(key) and not valid_value(key, state[key]): return false
	return true

static func valid_snapshot(state: Dictionary) -> bool:
	for group in ["scalar", "action", "locomotion", "effect"]:
		if not valid_group(state, group): return false
	return valid_relations(state) # Timers have a versioned migration; referential integrity needs world IDs.

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
						if value.get("unit") not in [10,11,22,24,25] or not _point([value.get("x"),value.get("y")]): return false
					_: return false
	return true

static func _reference(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= -1 and float(value) <= 2147483647

static func _point(value) -> bool:
	if not value is Array or value.size() != 2: return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func omissions(unit: Dictionary) -> Array:
	return unit.keys().filter(func(key): return not FIELDS.has(key))

static func snapshot_record(unit: Dictionary) -> Dictionary:
	var result := {}
	for key in fields("record"):
		var definition: Dictionary = FIELDS[key]
		result[definition.key] = decode(key, unit.get(key, definition.default)) if key != "officer" else int(unit.get("officer", {}).get("index", -1))
	return result

static func valid_record(record: Dictionary) -> bool:
	for key in fields("record"):
		var alias: String = FIELDS[key].key
		if not record.has(alias): continue
		if key == "officer":
			var value = record[alias]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < -1 or float(value) > 116: return false
		elif not valid_value(key, record[alias]): return false
	return true
