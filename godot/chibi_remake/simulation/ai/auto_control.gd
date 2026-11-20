extends Object
## AI auto-control policy. Owns the F2 delegation state machine; BattleState keeps
## only the persisted switch. F2 itself is a cheat request handled by CheatActions.
const Roles = preload("res://simulation/definitions/unit_roles.gd")
const CombatRules = preload("res://simulation/definitions/combat_rules.gd")
const State = preload("res://simulation/state/battle_state.gd")
const AUTO_PERIOD := preload("res://simulation/ai/ai_config.gd").THINK_PERIOD
var battle: State
var _dep_combat: Object
var _dep_player_commands: Object
var _dep_stratagems: Object

func _init(data: State) -> void:
	battle = data

func _step_auto_control() -> void:
	if not battle.auto_control or battle.sim_tick % AUTO_PERIOD != 0: return
	# The original F2 strategic policy is not fully recovered. Limit delegation to
	# idle combat troops and existing attack orders; never replace work/hold/orders.
	var extent := float(battle.map_data.terrainW) + float(battle.map_data.terrainH)
	for unit in battle.units:
		if not _dep_stratagems.eligible(unit, battle.player_owner): continue
		if str(unit.state) != "idle" or bool(unit.get("hold", false)) or float(unit.get("carry", 0)) > 0: continue
		if str(unit.get("team_kind", "")) == "worker": continue
		if not CombatRules.can_attack(unit) or Roles.is_worker(int(unit.unit)): continue
		if _dep_stratagems.active(unit) or not unit.get("effect_tasks", []).is_empty(): continue
		var target: Dictionary = _dep_combat._nearest_enemy(unit, extent)
		if not target.is_empty():
			_dep_player_commands.apply_autonomous("attack", battle.player_owner, int(unit.uid), int(target.uid))

func bind_dependencies(world: Object) -> void:
	_dep_combat = world.combat
	_dep_player_commands = world.player_commands
	_dep_stratagems = world.stratagems
