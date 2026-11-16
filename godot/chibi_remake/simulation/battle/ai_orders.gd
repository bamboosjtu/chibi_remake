extends RefCounted
## ai orders: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const REQUIRED_SERVICES := {"ai_economy": ["_ai_forming", "_working_construction_team", "ai_group_of", "ai_production_building"], "combat": ["_hostile_owners"], "command_groups": ["_cancel_unit_command"], "harvest_orders": ["_yield_of"], "movement": ["_path_to"]}
const Targets = preload("res://simulation/systems/ai_targets.gd")
var battle: State
var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)

func _init(data: State) -> void:
	battle = data

func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	var services := ports.acquire(["ai_economy", "movement", "command_groups"])
	if services.is_empty(): return
	var b: Dictionary = services.ai_economy.ai_production_building(owner)
	if b.is_empty():
		return
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0:
			continue
		if skip_groups.has(services.ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不归队
		if services.ai_economy._working_construction_team(u) or services.ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state != "idle":
			continue
		if Vector2(u.ax, u.ay).distance_to(Vector2(b.ax, b.ay)) > 900.0:
			var pts: Array = services.movement._path_to(u, Vector2(b.ax, b.ay), true)
			if pts.is_empty():
				continue
			services.command_groups._cancel_unit_command(u)
			u.state = "move"
			u.path = pts
			u.pi = 0

func ai_order_assault_l1(owner: int, skip_groups: Array = []) -> void:
	# Kept for older command clients; all maps now use the same confirmed policy.
	ai_order_assault(owner,skip_groups)

func _l1_target(player: int) -> Dictionary:
	var services := ports.acquire(["harvest_orders"])
	if services.is_empty(): return {}
	for u in battle.units:
		if int(u.get("owner", -1)) != player or not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0:
			continue
		if float(u.get("hp", 0.0)) <= 0.0:
			continue
		if bool(u.get("decor", false)) or services.harvest_orders._yield_of(int(u.get("unit", -1))) != "":
			continue
		if int(u.get("unit", -1)) == 26:   # 大旗，类别 5
			continue
		return u
	return {}

func ai_order_assault(owner: int, skip_groups: Array = []) -> void:
	var services := ports.acquire(["ai_economy", "command_groups"])
	if services.is_empty(): return
	# 先扫一遍：有任何单位正忙 → 整体放弃（原版行为）。撤退中的群不参与该判定。
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0:
			continue
		if not Targets.ordinary_attacker(u) and (u.get("officer",{}) as Dictionary).is_empty(): continue
		if skip_groups.has(services.ai_economy.ai_group_of(u)): continue
		if services.ai_economy._working_construction_team(u) or services.ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack" or u.state == "move":
			return
	var sent := 0
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
			continue
		if not Targets.ordinary_attacker(u) and (u.get("officer",{}) as Dictionary).is_empty(): continue
		if skip_groups.has(services.ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不进攻
		if services.ai_economy._working_construction_team(u) or services.ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		var e := Targets.select(battle.units,u,battle.player_owner,battle.scenario_mission,int(battle.map_data.cols))
		if not e.is_empty():
			services.command_groups._cancel_unit_command(u)
			u.state = "attack"
			u.target = e
			u.repath = 0.0
			u.path = []
			u.pi = 0
			sent += 1
	if sent > 0:
		print("AI 进攻：owner %d 投入 %d 个单位" % [owner, sent])

func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
	var services := ports.acquire(["ai_economy", "command_groups"])
	if services.is_empty(): return
	# The focus supplies an existing combat target, not an omniscient map query.
	var target = focus.get("target")
	if not target is Dictionary or not Targets.available(target,battle.player_owner): return
	var headquarters: Dictionary = {}
	for unit in battle.units:
		if int(unit.owner) == owner and int(unit.unit) in [0,1] and unit.alive and unit.die_t < 0 and not bool(unit.get("site",false)):
			headquarters = unit; break
	if headquarters.is_empty(): return
	var fp := Vector2(headquarters.ax,headquarters.ay)
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
			continue
		if skip_groups.has(services.ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不拦截
		if services.ai_economy._working_construction_team(u) or services.ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack":
			continue
		if not Targets.ordinary_attacker(u): continue
		if absf(float(u.ax)-fp.x) > radius or absf(float(u.ay)-fp.y) > radius: continue
		services.command_groups._cancel_unit_command(u)
		u.state = "attack"
		u.target = target

func ai_focus_unit(owner: int) -> Dictionary:
	for u in battle.units:
		if int(u.owner) == owner and not u.is_building and u.alive and u.die_t<0 and not bool(u.get("attached",false)) and int(u.get("site_inside_uid",-1)) < 0:
			var target = u.get("target")
			if not target is Dictionary or not Targets.available(target,battle.player_owner): continue
			return u
	return {}

func _nearest_enemy_threat(u: Dictionary) -> Dictionary:
	var services := ports.acquire(["combat"])
	if services.is_empty(): return {}
	# R09：普通进攻/拦截只找**人类玩家方**，多敌军地图不会出现电脑互攻。
	var best: Dictionary = {}
	var bd := 1.0e12
	var my_owner := int(u.get("owner", -1))
	var player_side := my_owner == battle.player_owner
	for e in battle.units:
		if not e.alive or e.die_t >= 0.0 or bool(e.get("attached",false)):
			continue
		if not services.combat._hostile_owners(my_owner, int(e.owner)):
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
