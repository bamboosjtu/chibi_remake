extends RefCounted
## ai orders: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/ai_orders_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	var b := ports.ai_production_building(owner)
	if b.is_empty():
		return
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0:
			continue
		if skip_groups.has(ports.ai_group_of(u)): continue   # R10：撤退中的群不归队
		if ports._working_construction_team(u) or ports._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state != "idle":
			continue
		if Vector2(u.ax, u.ay).distance_to(Vector2(b.ax, b.ay)) > 900.0:
			var pts := ports._path_to(u, Vector2(b.ax, b.ay), true)
			if pts.is_empty():
				continue
			ports._cancel_unit_command(u)
			u.state = "move"
			u.path = pts
			u.pi = 0

func ai_order_assault_l1(owner: int, skip_groups: Array = []) -> void:
	var target: Dictionary = _l1_target(battle.player_owner)
	if target.is_empty():
		return
	var groups: Array = []
	for u in battle.units:
		if int(u.get("owner", -1)) != owner or bool(u.get("is_building", false)) or not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0:
			continue
		if (u.get("officer", {}) as Dictionary).is_empty():
			continue
		var idx := int(u.officer.index)
		if skip_groups.has(idx): continue
		var group: Array = [u]
		for m in battle.units:
			if m != u and int(m.get("owner", -1)) == owner and int(m.get("group_officer", -1)) == idx and bool(m.get("alive", false)) and float(m.get("die_t", -1)) < 0.0:
				group.append(m)
		var idle := group.all(func(m): return str(m.get("state", "")) in ["idle", "hold"] and not bool(m.get("attached", false)))
		if idle:
			groups.append(group)
	if groups.is_empty():
		return
	var chosen: Array = groups[0]
	for u in chosen:
		ports._cancel_unit_command(u)
		u.state = "attack"
		u.target = target
		u.path = []
		u.pi = 0
		u.repath = 0.0
	print("AI L1 进攻：owner %d 群 %s → 槽位目标 %s(%d)" % [owner, str(chosen[0].officer.get("name", "?")), str(target.get("name", "?")), int(target.get("uid", -1))])

func _l1_target(player: int) -> Dictionary:
	for u in battle.units:
		if int(u.get("owner", -1)) != player or not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0:
			continue
		if float(u.get("hp", 0.0)) <= 0.0:
			continue
		if bool(u.get("decor", false)) or ports._yield_of(int(u.get("unit", -1))) != "":
			continue
		if int(u.get("unit", -1)) == 26:   # 大旗，类别 5
			continue
		return u
	return {}

func ai_order_assault(owner: int, skip_groups: Array = []) -> void:
	# 先扫一遍：有任何单位正忙 → 整体放弃（原版行为）。撤退中的群不参与该判定。
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0:
			continue
		if skip_groups.has(ports.ai_group_of(u)): continue
		if ports._working_construction_team(u) or ports._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack" or u.state == "move":
			return
	var sent := 0
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
			continue
		if skip_groups.has(ports.ai_group_of(u)): continue   # R10：撤退中的群不进攻
		if ports._working_construction_team(u) or ports._ai_forming(u) or bool(u.get("attached",false)): continue
		var e := _nearest_enemy_threat(u)
		if not e.is_empty():
			ports._cancel_unit_command(u)
			u.state = "attack"
			u.target = e
			u.repath = 0.0
			u.path = []
			u.pi = 0
			sent += 1
	if sent > 0:
		print("AI 进攻：owner %d 投入 %d 个单位" % [owner, sent])

func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
	var fp := Vector2(focus.ax, focus.ay)
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
			continue
		if skip_groups.has(ports.ai_group_of(u)): continue   # R10：撤退中的群不拦截
		if ports._working_construction_team(u) or ports._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack":
			continue
		if Vector2(u.ax, u.ay).distance_to(fp) > radius * 8.0:
			continue                       # ±90 单位 ≈ 90px，按等距格换算放宽
		var e := _nearest_enemy_threat(u)
		if not e.is_empty():
			ports._cancel_unit_command(u)
			u.state = "attack"
			u.target = e

func ai_focus_unit(owner: int) -> Dictionary:
	for u in battle.units:
		if int(u.owner) == owner and not u.is_building and u.alive and u.die_t<0 and not bool(u.get("attached",false)):
			return u
	return {}

func _nearest_enemy_threat(u: Dictionary) -> Dictionary:
	# R09：普通进攻/拦截只找**人类玩家方**，多敌军地图不会出现电脑互攻。
	var best: Dictionary = {}
	var bd := 1.0e12
	var my_owner := int(u.get("owner", -1))
	var player_side := my_owner == battle.player_owner
	for e in battle.units:
		if not e.alive or e.die_t >= 0.0 or bool(e.get("attached",false)):
			continue
		if not ports._hostile_owners(my_owner, int(e.owner)):
			continue
		if not player_side and int(e.owner) != battle.player_owner:
			continue                    # 显式冗余：AI 之间永远不是威胁
		var dx: float = e.ax - u.ax
		var dy: float = e.ay - u.ay
		var d2: float = dx * dx + dy * dy
		if d2 < bd:
			bd = d2
			best = e
	return best
