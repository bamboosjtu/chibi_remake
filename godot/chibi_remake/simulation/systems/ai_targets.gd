extends RefCounted
## Slot-order target selection from research/ai, independent of distance and view.
static func available(unit: Dictionary, player: int) -> bool:
	return int(unit.get("owner",-1)) == player and bool(unit.get("alive",false)) \
		and float(unit.get("hp",0)) > 0 and float(unit.get("die_t",-1)) < 0 \
		and not bool(unit.get("attached",false)) and int(unit.get("site_inside_uid",-1)) < 0

static func ordinary(unit: Dictionary) -> bool:
	var kind := int(unit.get("unit",-1))
	# Production buildings, resource objects, fortifications and flags are not
	# ordinary assault targets. Headquarters have their own original class (6).
	return kind in [0,1] or (kind >= 27 and not bool(unit.get("decor",false)))

static func ordinary_attacker(unit: Dictionary) -> bool:
	return (unit.get("officer",{}) as Dictionary).is_empty() and int(unit.get("unit",-1)) in [32,34,36,37,38,39,40,41,42,43,44,45,46,48,49]

static func select(units: Array, attacker: Dictionary, player: int, mission: int, columns: int) -> Dictionary:
	var hero := not (attacker.get("officer",{}) as Dictionary).is_empty()
	if hero:
		for target in units:
			if available(target,player) and int(target.unit) in [0,1] and not bool(target.get("site",false)): return target
		for target in units:
			if available(target,player) and not (target.get("officer",{}) as Dictionary).is_empty(): return target
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
