extends RefCounted
## A single synchronous decision's roster. Rebuild at the next decision rather
## than caching mutable ownership/group/attachment fields across ticks.
const Config = preload("res://simulation/battle_config.gd")
const Rules = preload("res://simulation/systems/unit_rules.gd")
var by_owner: Dictionary = {}
var groups: Dictionary = {}
var identities: Dictionary = {}
var scanned := 0

func _init(units: Array) -> void:
	for unit: Dictionary in units:
		scanned += 1
		identities[int(unit.uid)] = unit
		if not unit.alive or unit.die_t >= 0: continue
		var owner := int(unit.owner)
		if not by_owner.has(owner): by_owner[owner] = []
		by_owner[owner].append(unit)
		var group := Vector2i(owner, int(unit.get("group_officer", -1)))
		if not groups.has(group): groups[group] = []
		groups[group].append(unit)

func members(owner: int, officer: int) -> Array:
	return groups.get(Vector2i(owner, officer), [])

func construction_workers(commander: Dictionary) -> Array:
	if commander.is_empty() or not is_same(identities.get(int(commander.get("uid", -1))), commander): return []
	if not commander.alive or commander.die_t >= 0 or commander.get("attached", false): return []
	if int(commander.unit) not in Config.HERO_UNITS or commander.get("officer", {}).is_empty(): return []
	var count := 0
	var workers := []
	for member: Dictionary in members(int(commander.owner), int(commander.officer.index)):
		if member.is_building or member == commander: continue
		count += 1
		if count > Config.TEAM_MAX_MEMBERS or int(member.unit) not in Config.WORKER_UNITS: return []
		if Rules.can_build(member) and not member.get("attached", false): workers.append(member)
	return workers
