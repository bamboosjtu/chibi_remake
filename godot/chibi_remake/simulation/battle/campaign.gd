extends RefCounted
## campaign: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/campaign_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _force_counts(owner: int) -> Dictionary:
	var cu := 0
	var cb := 0
	for x in battle.units:
		if int(x.owner) != owner or not x.alive or x.die_t >= 0.0:
			continue
		if x.is_building:
			cb += 1
		else:
			cu += 1
	return {"units": cu, "buildings": cb}

func _objective_kind() -> String:
	if Config.SCRIPTED_OBJECTIVES.has(battle.scenario_mission):
		return "scripted"
	if Config.SCRIPTED_EVENT_MISSIONS.has(battle.scenario_mission):
		return "events"      # 有事件触发器，但胜负走默认规则
	return "none"

func _objective_eval() -> int:
	return battle.rules.tick() if battle.rules != null else 0

func _water_cell_count() -> int:
	var w: Array = battle.map_data.get("waterWalkable", [])
	var n := 0
	for v in w:
		if int(v) == 1:
			n += 1
	return n

func _check_end() -> void:
	var mine := _force_counts(battle.player_owner)
	battle.cnt_player = int(mine.units)
	# 敌对参战方：优先用战役表；没有定义时按"除我与中立(0)以外都是敌人"
	var foes: Array = []
	if battle.scenario_sides.size() > 1:
		for i in range(1, battle.scenario_sides.size()):
			foes.append(int((battle.scenario_sides[i] as Dictionary).get("owner", -1)))
	else:
		for x in battle.units:
			var o := int(x.owner)
			if o != battle.player_owner and o != 0 and not foes.has(o):
				foes.append(o)
	var enemy_units := 0
	var enemy_buildings := 0
	for o in foes:
		var c := _force_counts(int(o))
		enemy_units += int(c.units)
		enemy_buildings += int(c.buildings)
	battle.cnt_enemy = enemy_units
	battle.cnt_enemy_buildings = enemy_buildings
	if battle.game_end != 0:
		return
	if _objective_eval() == 1:
		# 专属出口与通用歼灭胜利分开：objective_done + task_latches 是脚本达成的证据。
		battle.game_end = 1
		ports._show_end(1)
		print("SCRIPTED VICTORY mission %d objective_done=%s" % [int(battle.scenario_mission), str(battle.objective_done)])
		return
	# 原版默认（歼灭战）：胜利 = **所有**敌对参战方的单位与建筑都清空
	if enemy_units == 0 and enemy_buildings == 0:
		battle.game_end = 1
		ports._show_end(1)
		print("VICTORY")
	# 失败 = (资源1 == 0 或 我军机动单位 == 0) 且 我军建筑 == 0
	elif (battle.gold <= 0.0 or int(mine.units) == 0) and int(mine.buildings) == 0:
		battle.game_end = 2
		ports._show_end(2)
		print("DEFEAT")

func _unit_name(unit_id: int) -> String:
	return str(battle.map_data.units.get(str(unit_id), {}).get("name", "unit %d" % unit_id))

func _show_end(kind: int) -> void:
	battle.effects.visual("show_end", [kind])
