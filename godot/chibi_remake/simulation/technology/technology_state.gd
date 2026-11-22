extends RefCounted
## Per-army research results. Scheduling and paid orders remain separate from effects.
const Technology = preload("res://simulation/definitions/technology_rules.gd")
## R01：科技生命加成的统一口径 —— 普通部队每级 +400 当前 HP，基础上限不变。
## 存档校验（含运输船载员）必须接受 hp > maxhp 的合法状态，但只在这个上限内。

## 允许的当前 HP 上限：基础上限 + 科技累计获得的当前兵力（不是替换 maxhp）。
## 返回 -1 表示字段本身非法。
static func hp_ceiling(maximum: Variant, base: Variant, bonus: Variant) -> float:
	if not (maximum is int or maximum is float) or not is_finite(float(maximum)) or float(maximum) < 0: return -1.0
	if not (base is int or base is float) or not is_finite(float(base)) or float(base) < 0: return -1.0
	if not (bonus is int or bonus is float) or not is_finite(float(bonus)) or float(bonus) < 0: return -1.0
	if float(bonus) > Technology.hp_per_level() * float(Technology.limits().level): return -1.0
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
		if not Technology.limits().has(key): return false
		var number: Variant = value[key]
		if not (number is int or number is float): return false
		if not is_finite(float(number)) or float(number) != floorf(float(number)) or float(number) < 0 or float(number) > int(Technology.limits()[key]): return false
	return true

## Completion is monotonic and idempotent, including replay after a save/restore.
static func complete(value: Dictionary, index: int) -> bool:
	if index < 0 or index >= Technology.table().size(): return false
	var completion: Dictionary = Technology.table()[index].completion
	if completion.is_empty(): return false
	var key: String = completion.keys()[0]
	var level := int(completion[key])
	if int(value.get(key, 0)) >= level: return false
	value[key] = level
	return true
