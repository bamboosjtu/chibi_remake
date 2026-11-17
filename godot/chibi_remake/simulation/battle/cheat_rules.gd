extends RefCounted
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## research/meta: confirmed state changes; no rendering or scene dependency.
const State = preload("res://simulation/battle_state.gd")
const AUTO_PERIOD := preload("res://simulation/systems/ai_config.gd").THINK_PERIOD
var battle: State
const REQUIRED_SERVICES := {"abilities": ["_jimou_caster_for_selection"], "combat": ["_nearest_enemy"], "command_groups": ["_cancel_unit_command"], "officer_pool": ["_sync_officer_to_pool"]}
var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)

func _init(data: State) -> void:
	battle = data

func _cheat_action(action: String) -> String:
	var services := ports.acquire(["abilities", "officer_pool"])
	if services.is_empty(): return ""
	if not battle.cheats_enabled: return ""
	match action:
		"auto":
			battle.auto_control = not battle.auto_control
			return "托管：%s（空闲战斗部队自动进攻可见敌人）" % _cheat_switch(battle.auto_control)
		"demote", "promote":
			var unit: Dictionary = services.abilities._jimou_caster_for_selection()
			if unit.is_empty(): return "请先选中我方武将"
			var officer: Dictionary = unit.officer
			officer.level = clampi(int(officer.get("level", 0)) + (-1 if action == "demote" else 1), 0, 9)
			services.officer_pool._sync_officer_to_pool(officer)
			return "%s：等级 %d（经验不变）" % [str(officer.get("name", "武将")), int(officer.level)]
		"ui":
			return "F5 界面/指针功能暂未开放"
		"build":
			battle.cheat_build_any = not battle.cheat_build_any
			return "取消建筑前置：%s（仍扣资源，须有合法落点）" % _cheat_switch(battle.cheat_build_any)
		"invulnerable":
			battle.cheat_invulnerable = not battle.cheat_invulnerable
			return "我方免伤：%s" % _cheat_switch(battle.cheat_invulnerable)
		"reveal":
			battle.cheat_reveal = not battle.cheat_reveal
			battle.visibility.set_full_reveal(battle.cheat_reveal)
			return "全图可见：%s" % _cheat_switch(battle.cheat_reveal)
		"resources":
			battle.gold += 10000.0
			battle.wood += 10000.0
			battle.food += 10000.0
			battle.stone += 10000.0
			return "金、木、粮、铁各增加 10000"
	return ""

func _cheat_switch(enabled: bool) -> String:
	return "开启" if enabled else "关闭"

func _step_auto_control() -> void:
	var services := ports.acquire(["combat", "command_groups"])
	if services.is_empty(): return
	if not battle.auto_control or battle.sim_tick % AUTO_PERIOD != 0: return
	# The original F2 strategic policy is not fully recovered. Limit delegation to
	# idle combat troops and existing attack orders; never replace work/hold/orders.
	var extent := float(battle.map_data.terrainW) + float(battle.map_data.terrainH)
	for unit in battle.units:
		if not battle.stratagems.eligible(unit, battle.player_owner): continue
		if str(unit.state) != "idle" or bool(unit.get("hold", false)) or float(unit.get("carry", 0)) > 0: continue
		if str(unit.get("team_kind", "")) == "worker": continue
		if not preload("res://simulation/systems/combat_rules.gd").can_attack(unit) or Roles.is_worker(int(unit.unit)): continue
		if battle.stratagems.active(unit) or not unit.get("effect_tasks", []).is_empty(): continue
		var target: Dictionary = services.combat._nearest_enemy(unit, extent)
		if not target.is_empty():
			services.command_groups._cancel_unit_command(unit)
			unit.target = target
			unit.state = "attack"
			unit.repath = 0.0
