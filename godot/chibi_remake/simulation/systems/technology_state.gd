extends RefCounted
## Per-army research results. Scheduling and paid orders remain separate from effects.
const LIMITS := {"level":3, "bow":3, "weapon":3, "armor":3, "catapult":2, "ship_atk":2, "ship_def":1}
## R01：科技生命加成的统一口径 —— 普通部队每级 +400 当前 HP，基础上限不变。
## 存档校验（含运输船载员）必须接受 hp > maxhp 的合法状态，但只在这个上限内。
const HP_PER_LEVEL := 400.0

## 允许的当前 HP 上限：基础上限 + 科技累计获得的当前兵力（不是替换 maxhp）。
## 返回 -1 表示字段本身非法。
static func hp_ceiling(maximum: Variant, base: Variant, bonus: Variant) -> float:
	if not (maximum is int or maximum is float) or not is_finite(float(maximum)) or float(maximum) < 0: return -1.0
	if not (base is int or base is float) or not is_finite(float(base)) or float(base) < 0: return -1.0
	if not (bonus is int or bonus is float) or not is_finite(float(bonus)) or float(bonus) < 0: return -1.0
	if float(bonus) > HP_PER_LEVEL * float(LIMITS.level): return -1.0
	return maxf(float(maximum), float(base) + float(bonus))

static func valid_hp(life: Variant, maximum: Variant, base: Variant, bonus: Variant) -> bool:
	if not (life is int or life is float) or not is_finite(float(life)) or float(life) < 0: return false
	var ceiling := hp_ceiling(maximum, base, bonus)
	return ceiling >= 0.0 and float(life) <= ceiling

static func initial() -> Dictionary:
	return {"level":0, "bow":0, "weapon":0, "armor":0, "catapult":0, "ship_atk":0, "ship_def":0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not LIMITS.has(key): return false
		var number: Variant = value[key]
		if not (number is int or number is float): return false
		if not is_finite(float(number)) or float(number) != floorf(float(number)) or float(number) < 0 or float(number) > int(LIMITS[key]): return false
	return true

## Completion is monotonic and idempotent, including replay after a save/restore.
static func complete(value: Dictionary, index: int) -> bool:
	var key := ""
	var level := 0
	if index in [0,1,2]: key = "level"; level = index + 1
	elif index in [3,4,5]: key = "bow"; level = index - 2
	elif index in [6,7,8]: key = "weapon"; level = index - 5
	elif index in [9,10,11]: key = "armor"; level = index - 8
	elif index in [18,19]: key = "catapult"; level = index - 17
	elif index in [20,21]: key = "ship_atk"; level = index - 19
	elif index == 22: key = "ship_def"; level = 1
	else: return false # Resource sales have their own economy transaction.
	if int(value.get(key, 0)) >= level: return false
	value[key] = level
	return true
