extends RefCounted
const Combat = preload("res://simulation/systems/combat_rules.gd")
## Local encounters are independent of the strategic AI's campaign assault gate.
## Stagger scans at 5 Hz; explicit marching, work, cargo, rest and hold orders win.
static func eligible(u: Dictionary) -> bool:
	return str(u.get("state", "")) == "idle" and not bool(u.get("hold", false)) \
		and not bool(u.get("is_building", false)) and not bool(u.get("attached", false)) \
		and int(u.get("site_inside_uid", -1)) < 0 and float(u.get("carry", 0)) <= 0 \
		and not preload("res://simulation/systems/stratagem_rules.gd").active(u) \
		and Combat.can_attack(u)

static func step(host: RefCounted, u: Dictionary, nearest_enemy: Callable) -> void:
	if not eligible(u) or (int(host.sim_tick) + int(u.uid)) % 6 != 0: return
	var radius: float = minf(8.0, float(u.get("vision", 8))) * float(host.tile_w)
	var enemy: Dictionary = nearest_enemy.call(u, radius)
	if enemy.is_empty(): return
	engage(u, enemy)
	var leader: int = int(u.get("group_officer", -1))
	if not (u.get("officer", {}) as Dictionary).is_empty(): leader = int(u.officer.index)
	if leader < 0: return
	for member in host.units:
		if not bool(member.alive) or float(member.die_t) >= 0 or int(member.owner) != int(u.owner): continue
		var same_team: bool = int(member.get("group_officer", -1)) == leader \
			or int((member.get("officer", {}) as Dictionary).get("index", -2)) == leader
		if same_team and eligible(member) and Vector2(member.ax-u.ax, member.ay-u.ay).length() <= radius:
			engage(member, enemy)

static func engage(u: Dictionary, enemy: Dictionary) -> void:
	u.target = enemy
	u.state = "attack"
	u.path = []
	u.pi = 0
	u.repath = 0.0
