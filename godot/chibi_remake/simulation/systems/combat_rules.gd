extends RefCounted
const Progression = preload("res://simulation/systems/officer_progression.gd")

const HERO_TYPES: Array = [29,31,33,35,52]
const B_ATTACK_TYPES: Array = [18,19,33,34,39,42,44,45,46,48,49,52]

static func can_attack(unit: Dictionary) -> bool:
	# 研究只改变计算值，不能给无武装的运输船增加攻击动作。
	if int(unit.get("unit", -1)) == 47: return false
	return float(unit.get("atk_range", 0)) > 0 and (float(unit.get("attack", 0)) > 0 or float(unit.get("attack_b", 0)) > 0)

static func ambush(unit:Dictionary) -> bool:
	return int(unit.get("ambush_t",0))>0 and int(unit.get("unit",-1)) in [32,45]

static func effective_range(unit:Dictionary) -> float:
	if ambush(unit):return float(unit.get("base_vision",5 if int(unit.unit)==32 else 7))
	return float(unit.get("atk_range",0))

static func grade(officer: Dictionary) -> int:
	if int(officer.get("tier",0)) not in [1,2,3,4]:return 0
	return int(Progression.cell(officer).grade)

static func hero(unit: Dictionary) -> bool:
	return int(unit.get("unit", -1)) in HERO_TYPES and not unit.get("officer", {}).is_empty()

static func attack(unit: Dictionary, channel_b: bool = false) -> float:
	var base := float(unit.get("attack_b" if channel_b else "attack", 0))
	if hero(unit):
		var officer: Dictionary = unit.officer
		return floorf((float(officer.get("might", 0)) + grade(officer)) * base / 100.0)
	return base + float(unit.get("attack_b_bonus" if channel_b else "attack_bonus", 0))

static func defence(unit: Dictionary, channel_b: bool = false) -> float:
	var base := float(unit.get("defence_b" if channel_b else "defence", 0))
	if hero(unit): return floorf(float(unit.officer.get("might", 0)) * base / 100.0)
	return base + float(unit.get("defence_b_bonus" if channel_b else "defence_bonus", 0))

static func damage(attacker: Dictionary, defender: Dictionary, channel_b: bool) -> float:
	if ambush(attacker):return 30.0 # effect8 bypasses defence
	# Hero attack/defence each use their researched integer formula.
	# Fixed-point subtraction keeps ordinary unit bonuses deterministic too.
	var attack_cents := roundi(attack(attacker, channel_b) * 100.0)
	var defence_cents := roundi(defence(defender, channel_b) * 100.0)
	return float(maxi(1, int(float(attack_cents - defence_cents) / 100.0)))
