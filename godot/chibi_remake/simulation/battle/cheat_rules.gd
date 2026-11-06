extends RefCounted
## research/meta: confirmed state changes; no rendering or scene dependency.
const Config = preload("res://simulation/battle_config.gd")
const State = preload("res://simulation/battle_state.gd")
const AUTO_PERIOD := preload("res://simulation/systems/ai_config.gd").THINK_PERIOD
var battle: State
var ports = preload("res://simulation/ports/cheat_rules_dependencies.gd").new()

func _init(data: State) -> void:
	battle = data

func _cheat_action(action: String) -> String:
	if not battle.cheats_enabled: return ""
	match action:
		"auto":
			battle.auto_control = not battle.auto_control
			return "托管：%s（空闲战斗部队自动进攻可见敌人）" % _cheat_switch(battle.auto_control)
		"demote", "promote":
			var unit := ports.selected_officer()
			if unit.is_empty(): return "请先选中我方武将"
			var officer: Dictionary = unit.officer
			officer.level = clampi(int(officer.get("level", 0)) + (-1 if action == "demote" else 1), 0, 9)
			ports.sync_officer(officer)
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
	if not battle.auto_control or battle.sim_tick % AUTO_PERIOD != 0: return
	# The original F2 strategic policy is not fully recovered. Limit delegation to
	# idle combat troops and existing attack orders; never replace work/hold/orders.
	var extent := float(battle.map_data.terrainW) + float(battle.map_data.terrainH)
	for unit in battle.units:
		if not battle.stratagems.eligible(unit, battle.player_owner): continue
		if str(unit.state) != "idle" or bool(unit.get("hold", false)) or float(unit.get("carry", 0)) > 0: continue
		if str(unit.get("team_kind", "")) == "worker": continue
		if not preload("res://simulation/systems/combat_rules.gd").can_attack(unit) or int(unit.unit) in Config.WORKER_UNITS: continue
		if battle.stratagems.active(unit) or not unit.get("effect_tasks", []).is_empty(): continue
		var target := ports.nearest(unit, extent)
		if not target.is_empty(): ports.attack(unit, target)
