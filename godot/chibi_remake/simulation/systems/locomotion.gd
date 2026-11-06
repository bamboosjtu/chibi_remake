extends RefCounted
## research/movements: shared two-update gait clock, independent screen facing.
## These fields only choose poses. Path direction, travel and combat stay authoritative.
const FIELDS := ["walk_tick", "move_facing", "turn_tick", "move_started", "move_turning"]
const FRAME_TICKS = preload("res://simulation/definitions/action_visual.gd").FRAME_TICKS

static func ensure(u: Dictionary) -> void:
	if bool(u.get("is_building", false)): return
	if not u.has("walk_tick"): u.walk_tick = 0
	if not u.has("move_facing"): u.move_facing = int(u.get("dir", 0)) & 7
	if not u.has("turn_tick"): u.turn_tick = 0
	if not u.has("move_started"): u.move_started = false
	if not u.has("move_turning"): u.move_turning = false

static func step(u: Dictionary) -> void:
	if bool(u.get("is_building", false)): return
	ensure(u)
	if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0 \
			or preload("res://simulation/systems/stratagem_rules.gd").active(u): return
	var moving := bool(u.get("moved", false))
	var desired := int(u.get("dir", 0)) & 7
	if moving: u.walk_tick = int(u.walk_tick) + 1
	# Preserve attack/repair timing and facing while actually performing the action.
	if not moving and str(u.get("state", "")) in ["attack", "repair"]:
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
	for field in ["walk_tick", "move_facing", "turn_tick"]:
		if not state.has(field): continue
		var v = state[field]
		if not (v is int or v is float) or not is_finite(float(v)) or float(v) != floorf(float(v)): return false
		if float(v) < 0 or float(v) > (7 if field == "move_facing" else 2147483647): return false
	for field in ["move_started", "move_turning"]:
		if state.has(field) and not state[field] is bool: return false
	return true

static func restore(state: Dictionary, u: Dictionary) -> void:
	# Visual construction may already have seeded defaults before saved dir is read.
	# An old snapshot must seed from that restored direction, not from spawn facing.
	for field in FIELDS: u.erase(field)
	for field in FIELDS:
		if state.has(field): u[field] = state[field]
	ensure(u)
