extends RefCounted
## abilities: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/abilities_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _jimou_caster_for_selection() -> Dictionary:
	for u in battle.selected:
		if battle.units.any(func(unit): return is_same(unit, u)) and bool(u.get("alive", false)) and u.die_t < 0 and int(u.owner) == battle.player_owner and not u.get("attached", false) and not bool(u.is_building) and not (u.get("officer", {}) as Dictionary).is_empty():
			return u
	return {}

func _reset_jimou() -> void:
	battle.jimou_pending = -1
	battle.jimou_caster = {}

func _jimou_begin(idx: int) -> void:
	if idx < 0 or idx >= Config.JIMOU_NAMES.size():
		return
	var caster := _jimou_caster_for_selection()
	if caster.is_empty():
		ports._feedback("没有武将部队可以施放计谋")
		return
	var lv: int = int((caster.get("officer", {}) as Dictionary).get("level", 0))
	var mask: int = int(Config.JIMOU_LV_MASK[mini(lv, Config.JIMOU_LV_MASK.size() - 1)])
	if (mask & (1 << idx)) == 0:
		ports._feedback("级别不够没有可用计谋")
		return
	if float(caster.get("mou", 0.0)) < float(Config.JIMOU_COST[idx]):
		ports._feedback("谋略值不够无法使用该计谋")
		return
	if battle.jimou_pending == idx:
		_reset_jimou()
		ports._feedback("已取消")
		return
	battle.jimou_pending = idx
	battle.jimou_caster = caster
	ports._feedback("%s（耗谋略 %d）：选%s目标（10 格内）" % [
		Config.JIMOU_NAMES[idx], int(Config.JIMOU_COST[idx]),
		"地面" if str(Config.JIMOU_SIDE[idx]) == "ground" else ("我方" if str(Config.JIMOU_SIDE[idx]) == "own" else "敌方")])

func _jimou_caster_invalid(caster: Dictionary, idx: int) -> String:
	if idx < 0 or idx >= Config.JIMOU_NAMES.size(): return "计谋编号无效"
	if caster.is_empty() or not battle.units.any(func(u):return is_same(u,caster)): return "施法武将已不在战场"
	if not bool(caster.get("alive", false)) or float(caster.get("die_t", -1)) >= 0.0: return "施法武将已阵亡"
	if bool(caster.get("attached", false)): return "施法武将已上船"
	if bool(caster.get("is_building", false)): return "建筑不能施放计谋"
	if int(caster.get("owner", -1)) != battle.player_owner: return "只能由我方武将施放计谋"
	var officer: Dictionary = caster.get("officer", {})
	if officer.is_empty(): return "施法武将已失去武将身份"
	var lv := int(officer.get("level", 0))
	var mask := int(Config.JIMOU_LV_MASK[mini(lv, Config.JIMOU_LV_MASK.size() - 1)])
	if (mask & (1 << idx)) == 0: return "级别不够没有可用计谋"
	if float(caster.get("mou", 0.0)) < float(Config.JIMOU_COST[idx]): return "谋略值不够无法使用该计谋"
	return ""

func _jimou_cast_at(pos: Vector2) -> void:
	var idx := battle.jimou_pending
	var caster: Dictionary = battle.jimou_caster
	var invalid := _jimou_caster_invalid(caster, idx)
	if invalid != "":
		_reset_jimou()
		ports._feedback(invalid)
		return
	var side := str(Config.JIMOU_SIDE[idx])
	var tgt: Dictionary = {}
	if side == "ground":
		tgt = {"ax": pos.x, "ay": pos.y, "name": "地面", "ground": true, "owner": -1}
	elif side == "own":
		tgt = ports._player_at(pos)
	else:
		tgt = ports._enemy_at(pos)
	if tgt.is_empty() or bool(tgt.get("is_building", false)):
		ports._feedback("计谋只能用于己方或敌军部队")
		return
	var d := Vector2(float(caster.ax), float(caster.ay)).distance_to(Vector2(float(tgt.ax), float(tgt.ay)))
	if d > Config.JIMOU_RANGE_CELLS * battle.tile_w:
		ports._feedback("目标须在视野（10 格）内")
		return
	# FUN_00424980: the clicked unit's team, including distant members, capped at15.
	var affected:Array=[tgt] if side=="ground" else battle.stratagems.target_team(tgt)
	if affected.is_empty():ports._feedback("目标部队已不在战场");return
	var msg := ""
	match idx:
		0:  # 状态1：每100tick恢复谋略，不直接增加士气。
			for o in affected:
				battle.stratagems.set_status(o,1)
			msg = "激励：%d 支部队加快谋略恢复" % affected.size()
		1:  # 加速：状态 2 开、状态 3 关
			for o in affected:
				battle.stratagems.set_status(o,2)
			msg = "加速：%d 支部队移速 ×%s" % [affected.size(),str(battle.stratagems.config().hasteMoveMultiplier)]
		2:  # 减速：状态 3 开、状态 2 关
			for o in affected:
				battle.stratagems.set_status(o,3)
			msg = "减速：%d 支部队移速 ×%s" % [affected.size(),str(battle.stratagems.config().slowMoveMultiplier)]
		3:  # 远视：状态 4（雾/视野更新）
			for o in affected:
				battle.stratagems.set_status(o,4)
			battle.visibility.update(battle.units, battle.player_owner)
			msg = "远视：%d 支部队揭示半径为%s格" % [affected.size(),str(battle.stratagems.config().farsightCells)]
		4:  # 混乱：状态 5 + 模式 0x1B（等待体）
			for o in affected:
				battle.stratagems.set_status(o,5)
			msg = "混乱：%d 支敌军将在当前任务结束后空转" % affected.size()
		5:  # 状态7 + 排队任务：每30次更新扫描视野，命中主将士气-50。
			for o in affected:battle.stratagems.set_status(o,7)
			msg="滚木：%d 支部队准备就绪"%affected.size()
		6:  # 状态6：步兵32/弓兵45获得视野射程和固定30伤害，无隐身。
			for o in affected:
				battle.stratagems.set_status(o,6)
			msg = "埋伏：%d 支部队就绪，步兵与弓兵获得特殊攻击" % affected.size()
		7:  # 恢复：+50 封顶（原版 +0x32 实证）
			var commander:Dictionary=ports._commander_for(tgt)
			if commander.is_empty():ports._feedback("恢复需要有主将的部队");return
			commander.hp=minf(float(commander.maxhp),float(commander.hp)+50.0)
			msg = "恢复：主将兵力 +50"
		8:  # 地面单格火场，5/9/.../97 更新各扣10，100更新结束。
			if not battle.fire_fields.ignite(pos):ports._feedback("此处无法施放火攻");return
			msg = "火攻：地面单格起火，注意避开友军"
	caster["mou"] = maxf(0.0, float(caster.get("mou", 0.0)) - float(Config.JIMOU_COST[idx]))
	_reset_jimou()
	ports._feedback(msg)

func _set_formation(idx: int) -> void:
	if battle.game_end != 0 or idx < 0 or idx >= Config.FORM_OFFSETS.size():
		return
	var caster := _jimou_caster_for_selection()
	var group: Array = _formation_group(caster)
	if group.is_empty():
		ports._feedback("没有可变换阵型的部队")
		return
	var level := clampi(int(caster.officer.get("level", 0)), 0, 9)
	if (int(Config.FORM_LV_MASK[level]) & (1 << idx)) == 0:
		ports._feedback("级别不够没有可用阵法")
		return
	var offs: Array = Config.FORM_OFFSETS[idx]
	var origin_cell := ports._cell_of_px(float(caster.get("ax", group[0].ax)), float(caster.get("ay", group[0].ay)))
	var n := 0
	for i in range(mini(group.size(), offs.size())):
		var u: Dictionary = group[i]
		var off: Array = offs[i]
		u["formation"] = idx
		u["fo_x"] = int(off[0])
		u["fo_y"] = int(off[1])
		# 逐支下发"移动到主将坐标 + 偏移"（原版 FUN_0045f710 尾部）。
		ports._move_unit_to_cell(u, _formation_target_cell(u, origin_cell))
		n += 1
	if n == 0:
		ports._feedback("没有可变换阵型的部队")
	else:
		ports._feedback("%d 支部队列阵：%s（纯队形，无攻防加成）" % [n, Config.FORM_NAMES[idx]])

func _formation_group(caster: Dictionary) -> Array:
	if caster.is_empty(): return []
	return battle.stratagems.target_team(caster)

func _formation_target_cell(u: Dictionary, cell: Vector2i) -> Vector2i:
	var fx := int(u.get("fo_x", 0))
	var fy := int(u.get("fo_y", 0))
	var c := cell + Vector2i(fx, fy)
	# 场地夹取 3..W−4 / 3..H−3（原版同款限制）。
	return Vector2i(clampi(c.x, 3, maxi(3, int(battle.map_data.rows) - 4)),
		clampi(c.y, 3, maxi(3, int(battle.map_data.cols) - 3)))

func _spd_mult(u: Dictionary) -> float:
	var m := 1.0
	if float(u.get("haste_t", 0.0)) > 0.0 and int(u.unit) not in [46,47,48,49,52]:
		m *= float(battle.stratagems.config().hasteMoveMultiplier)
	if float(u.get("slow_t", 0.0)) > 0.0:
		m *= float(battle.stratagems.config().slowMoveMultiplier)
	return m

func _duel_begin() -> void:
	if battle.game_end != 0: return
	var caster := _jimou_caster_for_selection()
	if caster.is_empty():
		ports._feedback("没有武将部队可以单挑")
		return
	if int(caster.get("unit", -1)) == 0x34:
		ports._feedback("旗舰不参与单挑")
		return
	ports._clear_pending()
	battle.duel_pending = true
	ports._feedback("单挑：选择敌方武将部队（10 格内）")

func _stamina_of(u: Dictionary) -> float:
	var o: Dictionary = u.get("officer", {})
	if o.is_empty():
		return 0.0
	return float(o.get("might", 0)) + preload("res://simulation/systems/combat_rules.gd").grade(o)

func _duel_accept(hp_a: float, _st_a: float, hp_b: float, st_b: float) -> bool:
	var power := int(((hp_a - st_b) * 4.0 * (1.0 / 60.0) + 1.0) * hp_a * hp_a * 0.006)
	if float(power) >= hp_b:
		return true
	return battle.simulation_rng.randi() % 5 == 2

func _roll_duel_damage(hp_a: float, hp_b: float, sta: float, stb: float) -> Array:
	var st_a := sta * 100.0 / 120.0
	var st_b := stb * 100.0 / 120.0
	# 交战结算 `FUN_004603e0`（一次确认 = 一次结算，单轮）：
	#   dmgA = trunc(((体力A−体力B)×4×(1/60)+1.0) × (rand()%5+4) × 兵力A% × 体力A% × 0.001)
	var dmg_a := int(((sta - stb) * 4.0 * (1.0 / 60.0) + 1.0)
		* float(battle.simulation_rng.randi() % 5 + 4) * hp_a * st_a * 0.001)
	var dmg_b := int(((stb - sta) * 4.0 * (1.0 / 60.0) + 1.0)
		* float(battle.simulation_rng.randi() % 5 + 4) * hp_b * st_b * 0.001)
	return [dmg_a, dmg_b]

func _finish_duel(caster: Dictionary, target: Dictionary, hp_a: float, hp_b: float, dmg_a: int, dmg_b: int, onm: String, enm: String) -> void:
	if not battle.units.any(func(u): return is_same(u, caster)) or not battle.units.any(func(u): return is_same(u, target)): return
	if float(dmg_a) >= hp_b:
		_write_force_pct(target, 0.0)
		_write_force_pct(caster, float(int(hp_a * 0.9)))     # 胜者保留 90% 兵力（整数除）
		ports._kill(target, caster)
		ports._feedback("%s 击败 %s，%s 退出战场（伤 %d）" % [onm, enm, enm, dmg_a])
	elif float(dmg_b) >= hp_a:
		_write_force_pct(caster, 0.0)
		_write_force_pct(target, float(int(hp_b * 0.9)))
		ports._kill(caster, target)
		ports._feedback("%s 被 %s 击败，退出战场（伤 %d）" % [onm, enm, dmg_b])
	else:
		_write_force_pct(caster, hp_a - float(dmg_b))
		_write_force_pct(target, hp_b - float(dmg_a))
		ports._feedback("单挑不分胜负：%s −%d ／ %s −%d" % [onm, dmg_b, enm, dmg_a])

func _force_pct(u: Dictionary) -> float:
	return clampf(float(u.get("hp", 0.0)) / maxf(1.0, float(u.get("maxhp", 1.0))) * 100.0, 0.0, 100.0)

func _write_force_pct(u: Dictionary, pct: float) -> void:
	var p := clampf(pct, 0.0, 100.0)
	u["hp"] = maxf(0.0, float(u.get("maxhp", 0.0)) * p / 100.0)
	if float(u["hp"]) <= 0.0 and bool(u.get("alive", false)):
		u["hp"] = 0.0

func _duel_at(pos: Vector2) -> void:
	if not battle.duel_pending: return
	battle.duel_pending = false # 一次目标确认只消费一次，不重放随机结算。
	if battle.game_end != 0: return
	var caster := _jimou_caster_for_selection()
	var target := ports._enemy_at(pos)
	if caster.is_empty() or target.is_empty() or (target.get("officer", {}) as Dictionary).is_empty():
		ports._feedback("单挑目标必须是将领部队")
		return
	if int(caster.get("unit", -1)) == 0x34 or int(target.get("unit", -1)) == 0x34:
		ports._feedback("旗舰不参与单挑")
		return
	var d := Vector2(float(caster.ax), float(caster.ay)).distance_to(Vector2(float(target.ax), float(target.ay)))
	if d > Config.JIMOU_RANGE_CELLS * battle.tile_w:
		ports._feedback("单挑对象须在视野（10 格）内")
		return
	var onm: String = str((caster.get("officer", {}) as Dictionary).get("name", "我军将军")).replace(" ", "")
	var enm: String = str((target.get("officer", {}) as Dictionary).get("name", "敌将")).replace(" ", "")
	var hp_a := _force_pct(caster)
	var hp_b := _force_pct(target)
	var sta := _stamina_of(caster)                 # 体力 = 武力 + 品级值（原值）
	var stb := _stamina_of(target)
	var st_a := sta * 100.0 / 120.0                # 界面/结算口径：体力 ×100/120
	var st_b := stb * 100.0 / 120.0
	if not _duel_accept(hp_a, st_a, hp_b, st_b):
		ports._feedback("%s将军拒绝单挑" % enm)
		return
	var damage := _roll_duel_damage(hp_a, hp_b, sta, stb)
	var dmg_a := int(damage[0])
	var dmg_b := int(damage[1])
	var outcome := "win" if float(dmg_a) >= hp_b else ("loss" if float(dmg_b) >= hp_a else "draw")
	var ticket: int = battle.effects.reserve_duel({"caster":int(caster.uid),"target":int(target.uid),"hp_a":hp_a,"hp_b":hp_b,"dmg_a":dmg_a,"dmg_b":dmg_b,"onm":onm,"enm":enm})
	if not battle.effects.duel(outcome, onm, enm, ticket): _resolve_duel(ticket)

func _resolve_duel(ticket: int) -> void:
	var record: Dictionary = battle.effects.take_duel(ticket)
	if record.is_empty(): return
	var caster: Dictionary = {}
	var target: Dictionary = {}
	for unit in battle.units:
		if int(unit.uid) == int(record.caster): caster = unit
		if int(unit.uid) == int(record.target): target = unit
	if caster.is_empty() or target.is_empty(): return
	_finish_duel(caster,target,float(record.hp_a),float(record.hp_b),int(record.dmg_a),int(record.dmg_b),str(record.onm),str(record.enm))
