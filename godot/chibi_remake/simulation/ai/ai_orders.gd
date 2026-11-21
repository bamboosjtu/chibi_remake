extends Object
var _player_commands: RefCounted
## ai orders: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const Targets = preload("res://simulation/ai/ai_targets.gd")
var battle: State
var _dep_ai_economy: Object
var _dep_combat: Object
var _dep_harvest_orders: Object

func _init(data: State) -> void:
	battle = data

func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	var b: Dictionary = _dep_ai_economy.ai_production_building(owner)
	if b.is_empty():
		return
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0:
			continue
		if skip_groups.has(_dep_ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不归队
		if _dep_ai_economy._working_construction_team(u) or _dep_ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state != "idle":
			continue
		if Vector2(u.ax, u.ay).distance_to(Vector2(b.ax, b.ay)) > 900.0:
			_player_commands.apply_autonomous("move", owner, int(u.uid), -1, -1, "", Vector2(b.ax, b.ay))

func _l1_target(player: int) -> Dictionary:
	for u in battle.units:
		if int(u.get("owner", -1)) != player or not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0:
			continue
		if float(u.get("hp", 0.0)) <= 0.0:
			continue
		if bool(u.get("decor", false)) or _dep_harvest_orders._yield_of(int(u.get("unit", -1))) != "":
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
		if not Targets.ordinary_attacker(u) and (u.get("officer",{}) as Dictionary).is_empty(): continue
		if skip_groups.has(_dep_ai_economy.ai_group_of(u)): continue
		if _dep_ai_economy._working_construction_team(u) or _dep_ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack" or u.state == "move":
			return
	var sent := 0
	for u in battle.units:
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/definitions/combat_rules.gd").can_attack(u):
			continue
		if not Targets.ordinary_attacker(u) and (u.get("officer",{}) as Dictionary).is_empty(): continue
		if skip_groups.has(_dep_ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不进攻
		if _dep_ai_economy._working_construction_team(u) or _dep_ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		var e := Targets.select(battle.units,u,battle.player_owner,battle.scenario_mission,int(battle.map_data.cols))
		if not e.is_empty() and _player_commands.apply_autonomous("attack", owner, int(u.uid), int(e.uid)):
			sent += 1
	if sent > 0:
		print("AI 进攻：owner %d 投入 %d 个单位" % [owner, sent])

func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
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
		if int(u.owner) != owner or u.is_building or not u.alive or u.die_t >= 0.0 or not preload("res://simulation/definitions/combat_rules.gd").can_attack(u):
			continue
		if skip_groups.has(_dep_ai_economy.ai_group_of(u)): continue   # R10：撤退中的群不拦截
		if _dep_ai_economy._working_construction_team(u) or _dep_ai_economy._ai_forming(u) or bool(u.get("attached",false)): continue
		if u.state == "attack":
			continue
		if not Targets.ordinary_attacker(u): continue
		if absf(float(u.ax)-fp.x) > radius or absf(float(u.ay)-fp.y) > radius: continue
		_player_commands.apply_autonomous("attack", owner, int(u.uid), int(target.uid))

func ai_focus_unit(owner: int) -> Dictionary:
	for u in battle.units:
		if int(u.owner) == owner and not u.is_building and u.alive and u.die_t<0 and not bool(u.get("attached",false)) and int(u.get("site_inside_uid",-1)) < 0:
			var target = u.get("target")
			if not target is Dictionary or not Targets.available(target,battle.player_owner): continue
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
		if not _dep_combat._hostile_owners(my_owner, int(e.owner)):
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

func bind_dependencies(world: Object) -> void:
	_dep_ai_economy = world.ai_economy
	_dep_combat = world.combat
	_dep_harvest_orders = world.harvest_orders
	_player_commands = world.player_commands
