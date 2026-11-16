extends RefCounted
## 攻击/修理共用整数节拍。动作相位只在等待结束后逐tick推进。
const Kernel=preload("res://simulation/native/math_kernel.gd")
const Schema = preload("res://simulation/definitions/unit_schema.gd")
static var FIELDS: Array = Schema.fields("action")

static func reset(unit: Dictionary) -> void:
	for key in FIELDS: unit[key] = Schema.default_value(key)

static func period(unit: Dictionary) -> int:
	var rate := maxi(1,int(unit.get("rate",100)))
	if int(unit.get("haste_t",0)) > 0: rate *= 2
	elif int(unit.get("slow_t",0)) > 0: rate = maxi(1,rate/2)
	return maxi(1,1000/rate)

static func clip_name(_unit: Dictionary) -> String:
	# 规格中的通用动作行是clips.walk；副动作不是默认攻击行。
	return preload("res://simulation/definitions/action_visual.gd").clip_name(_unit)

static func frames(unit: Dictionary) -> Array:
	var clips=unit.get("clips")
	if clips==null:return []
	var rows=clips.get(preload("res://simulation/definitions/action_visual.gd").CLIP_NAME)
	if rows==null or rows.is_empty(): return []
	return rows[(int(unit.get("dir",0)) & 7) % rows.size()]

static func step(unit: Dictionary, kind: String, target_uid: int, building := false) -> bool:
	var kernel:=Kernel.get_kernel()
	if kernel!=null:return kernel.step_clock(unit,kind,target_uid,building)
	return step_script(unit,kind,target_uid,building)

static func step_script(unit: Dictionary, kind: String, target_uid: int, building := false) -> bool:
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
	return Schema.valid_group(state, "action")

static func restore(state: Dictionary, unit: Dictionary) -> void:
	reset(unit)
	for key in FIELDS:
		if state.has(key): unit[key] = Schema.decode(key, state[key])

static func prepare_attack(unit: Dictionary,target: Dictionary,attack_range: float,width: float,tower: bool) -> int:
	var kernel:=Kernel.get_kernel()
	if kernel!=null:return int(kernel.prepare_attack(unit,target,attack_range,width,tower))
	return prepare_attack_script(unit,target,attack_range,width,tower)

static func prepare_attack_script(unit: Dictionary,target: Dictionary,attack_range: float,width: float,tower: bool) -> int:
	var offset:=Vector2(target.ax-unit.ax,target.ay-unit.ay)
	unit.dir=int(round(offset.angle()/(PI/4.0)))&7
	var strike:=step_script(unit,"attack",int(target.uid),tower)
	var reach:=attack_range*width
	return (1 if strike else 0)|(2 if offset.length_squared()<=reach*reach else 0)
