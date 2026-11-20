extends Object
const OfficerState = preload("res://simulation/officers/officer_state.gd")
## Cheat action handler. F2 only toggles the persisted auto-control switch; the
## policy/runtime stays in AI (auto_control.gd). F9 goes through Economy.
const VisibilityRuntime = preload("res://simulation/visibility/battle_visibility.gd")
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _visibility: VisibilityRuntime
var _dep_abilities: Object
var _dep_auto_control: Object
var _dep_economy: Object
var _dep_officer_pool: Object

func _init(data: State) -> void:
	battle = data

func action(action_name: String) -> String:
	if not battle.cheats_enabled: return ""
	match action_name:
		"auto":
			return "托管：%s（空闲战斗部队自动进攻可见敌人）" % _cheat_switch(_dep_auto_control.toggle())
		"demote", "promote":
			var unit: Dictionary = _dep_abilities._jimou_caster_for_selection()
			if unit.is_empty(): return "请先选中我方武将"
			var officer: Dictionary = unit.officer
			OfficerState.set_level(officer, clampi(int(officer.get("level", 0)) + (-1 if action_name == "demote" else 1), 0, 9))
			_dep_officer_pool._sync_officer_to_pool(officer)
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
			_visibility.set_full_reveal(battle.cheat_reveal)
			return "全图可见：%s" % _cheat_switch(battle.cheat_reveal)
		"resources":
			var res: Dictionary = _dep_economy.balance(battle.player_owner)
			for kind in ["gold", "wood", "food", "stone"]:
				res[kind] = float(res.get(kind, 0)) + 10000.0
			_dep_economy.write(battle.player_owner, res)
			return "金、木、粮、铁各增加 10000"
	return ""

func _cheat_switch(enabled: bool) -> String:
	return "开启" if enabled else "关闭"

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_auto_control = world.auto_control
	_dep_economy = world.economy
	_dep_officer_pool = world.officer_pool
	_visibility = world.visibility
