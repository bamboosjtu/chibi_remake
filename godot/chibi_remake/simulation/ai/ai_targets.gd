extends RefCounted
const Config = preload("res://simulation/definitions/battle_config.gd")
## Slot-order target selection from research/60-ai, independent of distance and view.
static func available(unit: Dictionary, player: int) -> bool:
	return int(unit.get("owner",-1)) == player and bool(unit.get("alive",false)) \
		and float(unit.get("hp",0)) > 0 and float(unit.get("die_t",-1)) < 0 \
		and not bool(unit.get("attached",false)) and int(unit.get("site_inside_uid",-1)) < 0

static func ordinary(unit: Dictionary) -> bool:
	var kind := int(unit.get("unit",-1))
	# Production buildings, resource objects, fortifications and flags are not
	# ordinary assault targets. Headquarters have their own original class (6).
	return kind in Config.HQ_TYPES or (kind >= 27 and not bool(unit.get("decor",false)))

static func ordinary_attacker(unit: Dictionary) -> bool:
	return (unit.get("officer",{}) as Dictionary).is_empty() and int(unit.get("unit",-1)) in [32,34,36,37,38,39,40,41,42,43,44,45,46,48,49]

static func select(units: Array, attacker: Dictionary, player: int, mission: int, columns: int) -> Dictionary:
	var hero := not (attacker.get("officer",{}) as Dictionary).is_empty()
	if hero:
		# FUN_00464B40：先找 class 6 的船坞（type 20），再找 class 7 的运输船（type 47）。
		# 陆战关玩家没有这两类目标时返回 1000 = 无目标，武将不会主动出击。
		for target in units:
			if available(target,player) and int(target.unit) == 20: return target
		for target in units:
			if available(target,player) and int(target.unit) == 47: return target
		return {}
	if mission == 14:
		for target in units:
			if available(target,player) and int(target.unit) in [0x23,0x24,0x26]: return target
		for target in units:
			if available(target,player) and not bool(target.get("is_building",false)) and float(target.get("B",0)) < columns * 0.5 and (ordinary_attacker(target) or not (target.get("officer",{}) as Dictionary).is_empty()):
				return target
		return {}
	for target in units:
		if available(target,player) and ordinary(target): return target
	return {}
