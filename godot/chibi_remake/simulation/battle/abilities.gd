extends Object
const VisibilityRuntime = preload("res://simulation/systems/battle_visibility.gd")
var _visibility: VisibilityRuntime
var _stratagems: RefCounted
var _fire_fields: RefCounted
const EffectsRuntime = preload("res://simulation/battle_effects.gd")
var _effects: EffectsRuntime
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## abilities: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var battle: State
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_movement: Object
var _dep_selection: Object
var _dep_world_orders: Object

func _init(data: State) -> void:
	battle = data

func _jimou_caster_for_selection(actors = null) -> Dictionary:
	for u in battle.selected if actors == null else actors:
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
		_effects.feedback("没有武将部队可以施放计谋")
		return
	var lv: int = int((caster.get("officer", {}) as Dictionary).get("level", 0))
	var mask: int = int(Config.JIMOU_LV_MASK[mini(lv, Config.JIMOU_LV_MASK.size() - 1)])
	if (mask & (1 << idx)) == 0:
		_effects.feedback("级别不够没有可用计谋")
		return
	if float(caster.get("mou", 0.0)) < float(Balance.abilities().cost[idx]):
		_effects.feedback("谋略值不够无法使用该计谋")
		return
	if battle.jimou_pending == idx:
		_reset_jimou()
		_effects.feedback("已取消")
		return
	battle.jimou_pending = idx
	battle.jimou_caster = caster
	_effects.feedback("%s（耗谋略 %d）：选%s目标（%s 格内）" % [
		Config.JIMOU_NAMES[idx], int(Balance.abilities().cost[idx]),
		"地面" if str(Config.JIMOU_SIDE[idx]) == "ground" else ("我方" if str(Config.JIMOU_SIDE[idx]) == "own" else "敌方"), str(Balance.abilities().rangeCells)])

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
	if float(caster.get("mou", 0.0)) < float(Balance.abilities().cost[idx]): return "谋略值不够无法使用该计谋"
	return ""

func _jimou_cast_at(pos: Vector2) -> void:
	var idx := battle.jimou_pending
	if _cast_jimou(pos, idx, battle.jimou_caster, jimou_target_at(pos, idx)):
		_reset_jimou()
	elif _jimou_caster_invalid(battle.jimou_caster, idx) != "":
		_reset_jimou()

func jimou_target_at(pos: Vector2, idx: int) -> Dictionary:
	if idx < 0 or idx >= Config.JIMOU_SIDE.size(): return {}
	var side := str(Config.JIMOU_SIDE[idx])
	var tgt: Dictionary = {}
	if side == "ground":
		tgt = {"ax": pos.x, "ay": pos.y, "name": "地面", "ground": true, "owner": -1}
	elif side == "own":
		tgt = _dep_selection._player_at(pos)
	else:
		tgt = _dep_selection._enemy_at(pos)
	return tgt

func _cast_jimou(pos: Vector2, idx: int, caster: Dictionary, tgt: Dictionary) -> bool:
	var invalid := _jimou_caster_invalid(caster, idx)
	if invalid != "":
		_effects.feedback(invalid)
		return false
	var side := str(Config.JIMOU_SIDE[idx])
	if tgt.is_empty() or bool(tgt.get("is_building", false)):
		_effects.feedback("计谋只能用于己方或敌军部队")
		return false
	var d := Vector2(float(caster.ax), float(caster.ay)).distance_to(Vector2(float(tgt.ax), float(tgt.ay)))
	if d > float(Balance.abilities().rangeCells) * battle.tile_w:
		_effects.feedback("目标超出计谋射程")
		return false
	# FUN_00424980: the clicked unit's team, including distant members, capped at15.
	var affected:Array=[tgt] if side=="ground" else _stratagems.target_team(tgt)
	if affected.is_empty():_effects.feedback("目标部队已不在战场");return false
	var msg := ""
	match idx:
		0:  # 状态1：每100tick恢复谋略，不直接增加士气。
			for o in affected:
				_stratagems.set_status(o,1)
			msg = "激励：%d 支部队加快谋略恢复" % affected.size()
		1:  # 加速：状态 2 开、状态 3 关
			for o in affected:
				_stratagems.set_status(o,2)
			msg = "加速：%d 支部队移速 ×%s" % [affected.size(),str(_stratagems.config().hasteMoveMultiplier)]
		2:  # 减速：状态 3 开、状态 2 关
			for o in affected:
				_stratagems.set_status(o,3)
			msg = "减速：%d 支部队移速 ×%s" % [affected.size(),str(_stratagems.config().slowMoveMultiplier)]
		3:  # 远视：状态 4（雾/视野更新）
			for o in affected:
				_stratagems.set_status(o,4)
			_visibility.update(battle.units, battle.player_owner)
			msg = "远视：%d 支部队揭示半径为%s格" % [affected.size(),str(_stratagems.config().farsightCells)]
		4:  # 混乱：状态 5 + 模式 0x1B（等待体）
			for o in affected:
				_stratagems.set_status(o,5)
			msg = "混乱：%d 支敌军将在当前任务结束后空转" % affected.size()
		5:  # 状态7 + 排队任务：每30次更新扫描视野，命中主将士气-50。
			for o in affected:_stratagems.set_status(o,7)
			msg="滚木：%d 支部队准备就绪"%affected.size()
		6:  # 状态6：步兵32/弓兵45获得视野射程和固定30伤害，无隐身。
			for o in affected:
				_stratagems.set_status(o,6)
			msg = "埋伏：%d 支部队就绪，步兵与弓兵获得特殊攻击" % affected.size()
		7:  # 恢复：+50 封顶（原版 +0x32 实证）
			var commander:Dictionary=_dep_command_groups._commander_for(tgt)
			if commander.is_empty():_effects.feedback("恢复需要有主将的部队");return false
			commander.hp=minf(float(commander.maxhp),float(commander.hp)+50.0)
			msg = "恢复：主将兵力 +50"
		8:  # 地面单格火场，5/9/.../97 更新各扣10，100更新结束。
			if not _fire_fields.ignite(pos):_effects.feedback("此处无法施放火攻");return false
			msg = "火攻：地面单格起火，注意避开友军"
	caster["mou"] = maxf(0.0, float(caster.get("mou", 0.0)) - float(Balance.abilities().cost[idx]))
	_effects.feedback(msg)
	return true

func _set_formation(idx: int, actors = null) -> bool:
	if battle.game_end != 0 or idx < 0 or idx >= Config.FORM_OFFSETS.size():
		return false
	var caster := _jimou_caster_for_selection(actors)
	var group: Array = _formation_group(caster)
	if group.is_empty():
		_effects.feedback("没有可变换阵型的部队")
		return false
	var level := clampi(int(caster.officer.get("level", 0)), 0, 9)
	if (int(Config.FORM_LV_MASK[level]) & (1 << idx)) == 0:
		_effects.feedback("级别不够没有可用阵法")
		return false
	var offs: Array = Config.FORM_OFFSETS[idx]
	var origin_cell: Vector2i = _dep_movement._cell_of_px(float(caster.get("ax", group[0].ax)), float(caster.get("ay", group[0].ay)))
	var n := 0
	for i in range(mini(group.size(), offs.size())):
		var u: Dictionary = group[i]
		var off: Array = offs[i]
		u["formation"] = idx
		u["fo_x"] = int(off[0])
		u["fo_y"] = int(off[1])
		# 逐支下发"移动到主将坐标 + 偏移"（原版 FUN_0045f710 尾部）。
		_dep_movement._move_unit_to_cell(u, _formation_target_cell(u, origin_cell))
		n += 1
	if n == 0:
		_effects.feedback("没有可变换阵型的部队")
	else:
		_effects.feedback("%d 支部队列阵：%s（纯队形，无攻防加成）" % [n, Config.FORM_NAMES[idx]])
	return n > 0

func _formation_group(caster: Dictionary) -> Array:
	if caster.is_empty(): return []
	return _stratagems.target_team(caster)

func _formation_target_cell(u: Dictionary, cell: Vector2i) -> Vector2i:
	var fx := int(u.get("fo_x", 0))
	var fy := int(u.get("fo_y", 0))
	var c := cell + Vector2i(fx, fy)
	# 场地夹取 3..W−4 / 3..H−3（原版同款限制）。
	return Vector2i(clampi(c.x, 3, maxi(3, int(battle.map_data.rows) - 4)),
		clampi(c.y, 3, maxi(3, int(battle.map_data.cols) - 3)))

func _spd_mult(u: Dictionary) -> float:
	var m := 1.0
	if float(u.get("haste_t", 0.0)) > 0.0 and not Roles.is_naval(int(u.unit)):
		m *= float(_stratagems.config().hasteMoveMultiplier)
	if float(u.get("slow_t", 0.0)) > 0.0:
		m *= float(_stratagems.config().slowMoveMultiplier)
	return m

func _duel_begin() -> void:
	if battle.game_end != 0: return
	var caster := _jimou_caster_for_selection()
	if caster.is_empty():
		_effects.feedback("没有武将部队可以单挑")
		return
	if int(caster.get("unit", -1)) == 0x34:
		_effects.feedback("旗舰不参与单挑")
		return
	_dep_world_orders._clear_pending()
	battle.duel_pending = true
	_effects.feedback("单挑：选择敌方武将部队（10 格内）")

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
		_dep_combat._kill(target, caster)
		_effects.feedback("%s 击败 %s，%s 退出战场（伤 %d）" % [onm, enm, enm, dmg_a])
	elif float(dmg_b) >= hp_a:
		_write_force_pct(caster, 0.0)
		_write_force_pct(target, float(int(hp_b * 0.9)))
		_dep_combat._kill(caster, target)
		_effects.feedback("%s 被 %s 击败，退出战场（伤 %d）" % [onm, enm, dmg_b])
	else:
		_write_force_pct(caster, hp_a - float(dmg_b))
		_write_force_pct(target, hp_b - float(dmg_a))
		_effects.feedback("单挑不分胜负：%s −%d ／ %s −%d" % [onm, dmg_b, enm, dmg_a])

func _force_pct(u: Dictionary) -> float:
	return clampf(float(u.get("hp", 0.0)) / maxf(1.0, float(u.get("maxhp", 1.0))) * 100.0, 0.0, 100.0)

func _write_force_pct(u: Dictionary, pct: float) -> void:
	var p := clampf(pct, 0.0, 100.0)
	u["hp"] = maxf(0.0, float(u.get("maxhp", 0.0)) * p / 100.0)
	if float(u["hp"]) <= 0.0 and bool(u.get("alive", false)):
		u["hp"] = 0.0

func _start_duel(caster: Dictionary, target: Dictionary) -> bool:
	if battle.game_end != 0: return false
	if caster.is_empty() or target.is_empty() or (target.get("officer", {}) as Dictionary).is_empty():
		_effects.feedback("单挑目标必须是将领部队")
		return false
	if int(caster.get("unit", -1)) == 0x34 or int(target.get("unit", -1)) == 0x34:
		_effects.feedback("旗舰不参与单挑")
		return false
	var d := Vector2(float(caster.ax), float(caster.ay)).distance_to(Vector2(float(target.ax), float(target.ay)))
	if d > float(Balance.abilities().rangeCells) * battle.tile_w:
		_effects.feedback("单挑对象超出范围")
		return false
	var onm: String = str((caster.get("officer", {}) as Dictionary).get("name", "我军将军")).replace(" ", "")
	var enm: String = str((target.get("officer", {}) as Dictionary).get("name", "敌将")).replace(" ", "")
	var hp_a := _force_pct(caster)
	var hp_b := _force_pct(target)
	var sta := _stamina_of(caster)                 # 体力 = 武力 + 品级值（原值）
	var stb := _stamina_of(target)
	var st_a := sta * 100.0 / 120.0                # 界面/结算口径：体力 ×100/120
	var st_b := stb * 100.0 / 120.0
	if not _duel_accept(hp_a, st_a, hp_b, st_b):
		_effects.feedback("%s将军拒绝单挑" % enm)
		return false
	var damage := _roll_duel_damage(hp_a, hp_b, sta, stb)
	var dmg_a := int(damage[0])
	var dmg_b := int(damage[1])
	var outcome := "win" if float(dmg_a) >= hp_b else ("loss" if float(dmg_b) >= hp_a else "draw")
	_finish_duel(caster, target, hp_a, hp_b, dmg_a, dmg_b, onm, enm)
	_effects.duel_requested.emit(outcome, onm, enm)
	return true

func bind_dependencies(world: Object) -> void:
	_dep_combat = world.combat
	_dep_command_groups = world.command_groups
	_dep_movement = world.movement
	_dep_selection = world.selection
	_dep_world_orders = world.world_orders
	_effects = world.effects
	_fire_fields = world.fire_fields
	_stratagems = world.stratagems
	_visibility = world.visibility
