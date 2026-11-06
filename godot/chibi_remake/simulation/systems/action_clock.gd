extends RefCounted
## 攻击/修理共用整数节拍。动作相位只在等待结束后逐tick推进。
const FIELDS := ["action_wait","action_phase","action_started","action_kind","action_target_uid"]

static func reset(unit: Dictionary) -> void:
	unit.action_wait = 0; unit.action_phase = 0; unit.action_started = false
	unit.action_kind = ""; unit.action_target_uid = -1

static func period(unit: Dictionary) -> int:
	var rate := maxi(1,int(unit.get("rate",100)))
	if int(unit.get("haste_t",0)) > 0: rate *= 2
	elif int(unit.get("slow_t",0)) > 0: rate = maxi(1,rate/2)
	return maxi(1,1000/rate)

static func clip_name(_unit: Dictionary) -> String:
	# 规格中的通用动作行是clips.walk；副动作不是默认攻击行。
	return preload("res://simulation/definitions/action_visual.gd").clip_name(_unit)

static func frames(unit: Dictionary) -> Array:
	var rows: Array = unit.get("clips",{}).get(clip_name(unit),[])
	if rows.is_empty(): return []
	return rows[(int(unit.get("dir",0)) & 7) % rows.size()]

static func step(unit: Dictionary, kind: String, target_uid: int, building := false) -> bool:
	if str(unit.get("action_kind","")) != kind or int(unit.get("action_target_uid",-1)) != target_uid:
		reset(unit); unit.action_kind = kind; unit.action_target_uid = target_uid
	if not bool(unit.get("action_started",false)):
		unit.action_started = true; unit.action_wait = 1
		return false # 命令首tick仅初始化，不推进动作相位。
	var wait := period(unit)
	unit.action_wait = mini(wait,int(unit.action_wait)+1)
	if int(unit.action_wait) < wait: return false
	if not building:
		var length := frames(unit).size()
		if length == 0: return false
		unit.action_phase = (int(unit.action_phase)+1) % length
		if int(unit.action_phase) != 2: return false
	unit.action_wait = 0
	return true # 相位保留到下一轮；N<3始终不会返回true。

static func valid_snapshot(state: Dictionary) -> bool:
	for key in ["action_wait","action_phase","action_target_uid"]:
		if not state.has(key): continue
		var value = state[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
		var maximum := 1000 if key == "action_wait" else (23 if key == "action_phase" else 2147483647)
		if float(value) < (-1 if key == "action_target_uid" else 0) or float(value) > maximum: return false
	if state.has("action_started") and not state.action_started is bool: return false
	if state.has("action_kind") and state.action_kind not in ["","attack","repair"]: return false
	return true

static func restore(state: Dictionary, unit: Dictionary) -> void:
	reset(unit)
	for key in FIELDS:
		if state.has(key): unit[key] = int(state[key]) if key in ["action_wait","action_phase","action_target_uid"] else state[key]
