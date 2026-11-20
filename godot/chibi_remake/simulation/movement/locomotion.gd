extends RefCounted
## research/movements: shared two-update gait clock, independent screen facing.
## These fields only choose poses. Path direction, travel and combat stay authoritative.
const Kernel=preload("res://simulation/native/math_kernel.gd")
const Schema = preload("res://simulation/units/unit_schema.gd")
static var FIELDS: Array = Schema.fields("locomotion")
const STATIONARY_ACTIONS := ["attack","repair"]
const FRAME_TICKS = preload("res://simulation/definitions/timing/action_visual.gd").FRAME_TICKS

static func ensure(u: Dictionary) -> void:
	if bool(u.get("is_building", false)): return
	for key in FIELDS:
		if not u.has(key): u[key] = (int(u.get("dir",0)) & 7) if key == "move_facing" else Schema.default_value(key)

static func step(u: Dictionary) -> void:
	var kernel:=Kernel.get_kernel()
	if kernel!=null:kernel.step_locomotion(u);return
	step_script(u)

static func step_script(u: Dictionary) -> void:
	if bool(u.get("is_building", false)): return
	ensure(u)
	if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0 \
			or preload("res://simulation/combat/stratagem_rules.gd").active(u): return
	var moving := bool(u.get("moved", false))
	var desired := int(u.get("dir", 0)) & 7
	if not moving and int(u.move_facing)==desired and not bool(u.move_started) and not bool(u.move_turning) and int(u.turn_tick)==0:return
	if moving: u.walk_tick = int(u.walk_tick) + 1
	# Preserve attack/repair timing and facing while actually performing the action.
	if not moving and str(u.get("state", "")) in STATIONARY_ACTIONS:
		u.move_facing = desired; u.move_turning = false; u.turn_tick = 0
	elif int(u.move_facing) != desired:
		u.move_turning = true; u.turn_tick = int(u.turn_tick) + 1
		if int(u.turn_tick) % FRAME_TICKS == 0:
			var difference := (desired - int(u.move_facing) + 8) % 8
			u.move_facing = (int(u.move_facing) + (1 if difference <= 4 else -1) + 8) % 8
	elif moving and not bool(u.move_started):
		u.move_turning = true; u.turn_tick = 1
	elif bool(u.move_turning) and int(u.turn_tick) < FRAME_TICKS:
		u.turn_tick = int(u.turn_tick) + 1
	else:
		u.move_turning = false; u.turn_tick = 0
	u.move_started = moving

static func valid_snapshot(state: Dictionary) -> bool:
	return Schema.valid_group(state, "locomotion")

static func restore(state: Dictionary, u: Dictionary) -> void:
	for field in FIELDS: u[field] = Schema.decode(field,state[field])
