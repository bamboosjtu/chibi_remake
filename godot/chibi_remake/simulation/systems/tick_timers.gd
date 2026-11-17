extends RefCounted
## Persisted durations are integer logic ticks.
## Fire fields own their separate global effect clock.
const REST_PERIOD = preload("res://simulation/battle_config.gd").REST_TICKS
const BUILD_PERIOD = preload("res://simulation/battle_config.gd").BUILD_STEP_TICKS
static var STATUS_DURATION: int = int(Schema.FIELDS.inspired_t.max)
const Schema = preload("res://simulation/definitions/unit_schema.gd")
static var STATUS_KEYS: Array = Schema.fields("status")
static var ELAPSED_PERIODS: Dictionary = _elapsed_periods()

static func _elapsed_periods() -> Dictionary:
	var result := {}
	for key in Schema.fields("elapsed"): result[key] = int(Schema.FIELDS[key].max) + 1
	return result

static func valid_snapshot(state: Dictionary) -> bool:
	for key in STATUS_KEYS + ELAPSED_PERIODS.keys():
		if not state.has(key): continue
		var value = state[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
			return false
		var limit := STATUS_DURATION if key in STATUS_KEYS else int(ELAPSED_PERIODS[key])
		if float(value) != floorf(float(value)): return false
		if float(value) > limit or (ELAPSED_PERIODS.has(key) and float(value) == limit): return false
	return true

static func restore(state: Dictionary, unit: Dictionary) -> void:
	for key in STATUS_KEYS + ELAPSED_PERIODS.keys():
		unit[key] = int(state[key])

static func step_statuses(unit: Dictionary) -> void:
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null:kernel.step_timers(unit);return
	step_statuses_script(unit)

static func step_statuses_script(unit: Dictionary) -> void:
	for key in STATUS_KEYS:
		var remaining:=int(unit.get(key,0))
		if remaining>0:unit[key]=remaining-1
