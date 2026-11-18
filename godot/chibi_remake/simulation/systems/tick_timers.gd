extends RefCounted
## Persisted durations are integer logic ticks.
## Fire fields own their separate global effect clock.
static var STATUS_DURATION: int = int(Schema.FIELDS.inspired_t.max)
const Schema = preload("res://simulation/definitions/unit_schema.gd")
static var STATUS_KEYS: Array = Schema.fields("status")
static var ELAPSED_KEYS: Array = Schema.fields("elapsed")

static func valid_snapshot(state: Dictionary) -> bool:
	return Schema.valid_group(state, "status") and Schema.valid_group(state, "elapsed")

static func restore(state: Dictionary, unit: Dictionary) -> void:
	for key in STATUS_KEYS + ELAPSED_KEYS:
		unit[key] = int(state[key])

static func step_statuses(unit: Dictionary) -> void:
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null:kernel.step_timers(unit);return
	step_statuses_script(unit)

static func step_statuses_script(unit: Dictionary) -> void:
	for key in STATUS_KEYS:
		var remaining:=int(unit.get(key,0))
		if remaining>0:unit[key]=remaining-1
