extends RefCounted
## technology: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/technology_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _is_worker_unit(u: Dictionary) -> bool:
	return int(u.get("unit", -1)) in Config.WORKER_UNITS

func _ai_side(owner: int) -> Dictionary:
	for i in range(battle.scenario_sides.size()):
		var sd: Dictionary = battle.scenario_sides[i]
		if int(sd.get("owner", -1)) == owner:
			return sd
	return {}

func ai_tech_gate(owner: int) -> int:
	var sd := _ai_side(owner)
	var init: Array = sd.get("init", [])
	return int(init[1]) if init.size() > 1 else 0

func tech_row(idx: int) -> Dictionary:
	if idx < 0 or idx >= Config.TECH_TABLE.size():
		return {}
	return Config.TECH_TABLE[idx]

func tech_is_sell(idx: int) -> bool:
	# 12–17 是卖资源行（§11.3 尾注：不是经济研究）。
	return idx >= 12 and idx <= 17

func _tech_line_of(idx: int) -> String:
	for line in Config.TECH_LINES.keys():
		var ids: Array = Config.TECH_LINES[line]
		if ids.has(idx):
			return str(line)
	return ""

func _tech_line_pos(idx: int) -> int:
	var line := _tech_line_of(idx)
	if line == "":
		return -1
	var ids: Array = Config.TECH_LINES[line]
	return ids.find(idx)

func _tech_line_progress(line: String, owner := -1) -> int:
	var state := _tech_for(battle.player_owner if owner < 0 else owner)
	match line:
		"hq": return int(state.get("level", 0))
		"bow": return int(state.get("bow", 0))
		"weapon": return int(state.get("weapon", 0))
		"armor": return int(state.get("armor", 0))
		"catapult": return int(state.get("catapult", 0))
		# 船坞线按 20→21→22 顺序（快船→战船→装甲）；船防只由 22 置位。
		"ship": return int(state.get("ship_atk", 0)) + int(state.get("ship_def", 0))
	return 0

func tech_is_completed(idx: int) -> bool:
	var line := _tech_line_of(idx)
	if line == "" or line == "sell":
		return false
	var pos := _tech_line_pos(idx)
	return pos >= 0 and pos < _tech_line_progress(line)

func tech_is_next(idx: int) -> bool:
	if tech_is_sell(idx):
		return true
	var line := _tech_line_of(idx)
	if line == "":
		return false
	return _tech_line_pos(idx) == _tech_line_progress(line)

func tech_next_index(line: String) -> int:
	var ids: Array = Config.TECH_LINES.get(line, [])
	var p := _tech_line_progress(line)
	if p < 0 or p >= ids.size():
		return -1
	return int(ids[p])

func tech_rows_for_building(bid: int) -> Array:
	var out: Array = []
	var lines: Array = Config.TECH_BUILDING_LINES.get(bid, [])
	for line_v in lines:
		var line := str(line_v)
		if line == "hq":
			var nxt := tech_next_index("hq")
			if nxt >= 0 and ai_tech_gate(battle.player_owner) >= nxt + 2:
				out.append(nxt)
			continue
		var ids: Array = Config.TECH_LINES.get(line, [])
		for id_v in ids:
			var idx := int(id_v)
			if not tech_is_completed(idx):
				out.append(idx)
	return out

func tech_cost(idx: int) -> Dictionary:
	var row := tech_row(idx)
	var out := {"gold": 0.0, "wood": 0.0, "stone": 0.0, "food": 0.0}
	if row.is_empty():
		return out
	var v: Array = row.get("v", [])
	if tech_is_sell(idx):
		var kind := str(row.get("sell", ""))
		var amount := 0.0
		if kind == "wood" and v.size() > 1:
			amount = float(v[1])
		elif kind == "stone" and v.size() > 2:
			amount = float(v[2])
		elif kind == "food" and v.size() > 3:
			amount = float(v[3])
		if out.has(kind):
			out[kind] = amount
		return out
	out["gold"] = float(v[0]) if v.size() > 0 else 0.0
	out["wood"] = float(v[1]) if v.size() > 1 else 0.0
	out["stone"] = float(v[2]) if v.size() > 2 else 0.0
	out["food"] = float(v[3]) if v.size() > 3 else 0.0
	return out

func tech_gold_gain(idx: int) -> float:
	if not tech_is_sell(idx):
		return 0.0
	var v: Array = tech_row(idx).get("v", [])
	return float(v[0]) if v.size() > 0 else 0.0

func tech_cost_text(idx: int) -> String:
	var cost := tech_cost(idx)
	if tech_is_sell(idx):
		var kind := str(tech_row(idx).get("sell", ""))
		var label: String = str({"wood": "木", "stone": "石", "food": "粮"}.get(kind, "?"))
		return "金+%.0f %s−%.0f" % [tech_gold_gain(idx), str(label), float(cost.get(kind, 0.0))]
	var keys: Array = ["gold", "wood", "stone", "food"]
	var names: Array = ["金", "木", "石", "粮"]
	var parts: PackedStringArray = PackedStringArray()
	for i in range(keys.size()):
		var val := float(cost.get(keys[i], 0.0))
		if val > 0.0:
			parts.append("%s%.0f" % [str(names[i]), val])
	return " ".join(parts) if parts.size() > 0 else "免费"

func tech_effect_desc(idx: int) -> String:
	match idx:
		0, 1, 2: return "现有及新建部队、建筑生命值 +400（箭楼除外，每级累加）"
		3, 4, 5: return "普通兵种各档射击加成：%s" % _tech_four_effects(idx)
		6, 7, 8: return "普通兵种各档近战加成：%s" % _tech_four_effects(idx)
		9, 10, 11: return "普通兵种各档防御加成：%s" % _tech_four_effects(idx)
		12, 13, 14, 15, 16, 17: return tech_cost_text(idx)
		18, 19: return "投石车攻击加成 +%d" % (10 * (idx - 17))
		20: return "快船射击加成 +6"
		21: return "战船射击 +15；连船防御 +15"
		22: return "快船防御 +6；战船防御 +10"
	return ""

func _tech_four_effects(idx: int) -> String:
	var values: Array = Config.TECH_TABLE[idx].v
	return "+%d / +%d / +%d / +%d" % [values[4],values[5],values[6],values[7]]

func tech_tip(idx: int) -> String:
	if tech_is_sell(idx):
		return "占用钱庄200tick；开始扣除资源，完成获得金钱，取消返还75%资源"
	return "预计%.1f秒；费用开始即扣，完成时生效" % (Config.TECH_TICKS * battle.clock.period())

func tech_block_reason(idx: int) -> String:
	var row := tech_row(idx)
	if row.is_empty():
		return "无此科技"
	var nm := str(row.get("name", "?"))
	if tech_is_sell(idx):
		return ""
	if tech_is_completed(idx):
		return "「%s」已研发" % nm
	var line := _tech_line_of(idx)
	if line == "":
		return "未知科技线"
	var pos := _tech_line_pos(idx)
	var prog := _tech_line_progress(line)
	if pos > prog:
		var ids: Array = Config.TECH_LINES[line]
		var prev := {}
		if prog >= 0 and prog < ids.size():
			prev = tech_row(int(ids[prog]))
		return "需先完成「%s」" % str(prev.get("name", "前置科技"))
	if pos < prog:
		return "「%s」已研发" % nm
	# 帅帐升级门槛（§11.3 / FUN_00426e40）：Lv1 需木材场+武器库且单位>1；
	# Lv2 同两项且单位>2；Lv3 需单位>3 且弓术/兵器等级均 ≥2。
	if line == "hq":
		if ai_tech_gate(battle.player_owner) < idx + 2: return "本关尚未开放该等级大本营"
		var n := _player_unit_count()
		var has_wood := _has_player_building([4, 5])
		var has_armory := _has_player_building([2, 3])
		if idx == 0:
			if not has_wood:
				return "需先建成木材场（类型 4/5）"
			if not has_armory:
				return "需先建成武器库（类型 2/3）"
			if n <= 1:
				return "需至少2个战斗单位（当前 %d）" % n
		elif idx == 1:
			if not has_wood:
				return "需先建成木材场（类型 4/5）"
			if not has_armory:
				return "需先建成武器库（类型 2/3）"
			if n <= 2:
				return "需至少3个战斗单位（当前 %d）" % n
		elif idx == 2:
			if n <= 3:
				return "需至少4个战斗单位（当前 %d）" % n
			if int(battle.player_tech.get("bow", 0)) < 2:
				return "需弓术等级 ≥ 2（当前 %d）" % int(battle.player_tech.get("bow", 0))
			if int(battle.player_tech.get("weapon", 0)) < 2:
				return "需兵器等级 ≥ 2（当前 %d）" % int(battle.player_tech.get("weapon", 0))
	return ""

func tech_unlocked(idx: int) -> bool:
	return tech_block_reason(idx) == ""

func _player_unit_count() -> int:
	return _combat_member_count(battle.player_owner)

func _combat_member_count(owner: int) -> int:
	var n := 0
	for u in battle.units:
		if bool(u.get("alive", false)) and u.die_t < 0 and not bool(u.is_building) and not _is_worker_unit(u) and float(u.get("attack",0)) > 0 and u.get("officer", {}).is_empty() and int(u.get("owner", -1)) == owner:
			n += 1
	return n

func _has_player_building(ids: Array) -> bool:
	for u in battle.units:
		# 只算**建成**的建筑：工地（site=true）还没完工，不能当帅帐升级前置。
		if bool(u.get("alive", false)) and u.die_t < 0 and bool(u.is_building) and not bool(u.get("site", false)) \
				and int(u.get("owner", -1)) == battle.player_owner and ids.has(int(u.get("unit", -1))):
			return true
	return false

func _research_for_building(building: Dictionary) -> Dictionary:
	if building.is_empty(): return {}
	for job in battle.research_jobs:
		if int(job.buildingUid) == int(building.uid): return job
	return {}

func _selected_research_building() -> Dictionary:
	for building in battle.selected:
		if building is Dictionary and battle.units.any(func(u):return is_same(u,building)) and building.is_building and int(building.owner) == battle.player_owner:
			return building
	return {}

func _building_work_busy(building: Dictionary) -> bool:
	return bool(building.get("site",false)) or battle.trainings.any(func(tr):return is_same(tr.b,building)) or not _research_for_building(building).is_empty() or (int(building.owner) == battle.player_owner and not battle.tech_progress.is_empty())

func _queue_research(owner: int, building: Dictionary, idx: int, ai_dispatch := false) -> bool:
	if idx < 0 or idx >= Config.TECH_TABLE.size() or building.is_empty(): return false
	if not battle.units.any(func(u):return is_same(u,building)) or not building.alive or building.die_t >= 0 or int(building.owner) != owner or not building.is_building or _building_work_busy(building): return false
	var line := _tech_line_of(idx)
	var lines: Array = Config.TECH_BUILDING_LINES.get(int(building.unit),[])
	if ai_dispatch and int(building.unit) in [4,5]: lines = ["bow"]
	if not lines.has(line): return false
	if not tech_is_sell(idx) and _tech_line_pos(idx) != _tech_line_progress(line,owner): return false
	if battle.research_jobs.any(func(job):return int(job.owner) == owner and int(job.tech) == idx and not tech_is_sell(idx)): return false
	var cost := tech_cost(idx)
	if not battle.economy.pay(owner,cost): return false
	battle.research_jobs.append({"buildingUid":int(building.uid),"owner":owner,"tech":idx,"t":0,"cost":cost})
	return true

func _start_tech(idx: int) -> bool:
	if battle.game_end != 0: return false
	var building := _selected_research_building()
	if building.is_empty():
		ports._feedback("先选中已建成的科技建筑"); return false
	if _building_work_busy(building):
		ports._feedback("该建筑正在工作，请先取消或等待完成"); return false
	var reason := tech_block_reason(idx)
	if reason != "":
		ports._feedback("无法研究：" + reason); return false
	if not _queue_research(battle.player_owner,building,idx):
		ports._feedback("无法开始：检查建筑、前置研究及资源"); return false
	ports._feedback("开始%s「%s」：%s" % ["出售" if tech_is_sell(idx) else "研究",str(tech_row(idx).get("name","?")),tech_cost_text(idx)])
	return true

func _process_tech(_delta: float) -> void:
	# v4-v6旧档的无引用单项研究继续完成；新订单全部使用建筑引用。
	if not battle.tech_progress.is_empty():
		battle.tech_progress.t = int(battle.tech_progress.get("t",0)) + 1
		if int(battle.tech_progress.t) >= Config.TECH_TICKS:
			var idx := int(battle.tech_progress.tech); battle.tech_progress = {}
			_apply_tech_effects(idx)
	var by_uid := {}
	if not battle.research_jobs.is_empty():
		for unit in battle.units: by_uid[int(unit.uid)] = unit
	for i in range(battle.research_jobs.size()-1,-1,-1):
		var job: Dictionary = battle.research_jobs[i]
		var building: Dictionary = by_uid.get(int(job.buildingUid), {})
		if building.is_empty() or not building.alive or building.die_t >= 0 or int(building.owner) != int(job.owner):
			battle.research_jobs.remove_at(i); continue
		job.t = int(job.t) + 1
		if int(job.t) < Config.TECH_TICKS: continue
		battle.research_jobs.remove_at(i)
		if tech_is_sell(int(job.tech)):
			var balance: Dictionary = battle.economy.balance(int(job.owner))
			balance.gold += tech_gold_gain(int(job.tech)); battle.economy.write(int(job.owner),balance)
		else: _apply_tech_effects(int(job.tech),int(job.owner))

func _tech_for(owner: int) -> Dictionary:
	if owner == battle.player_owner: return battle.player_tech
	if not battle.army_tech.has(owner): battle.army_tech[owner] = preload("res://simulation/systems/technology_state.gd").initial()
	return battle.army_tech[owner]

func _apply_tech_effects(idx: int, owner := -1) -> void:
	if owner < 0: owner = battle.player_owner
	if owner <= 0 or battle.scenario_sides.all(func(side): return int(side.owner) != owner): return
	var state := _tech_for(owner)
	if not preload("res://simulation/systems/technology_state.gd").complete(state, idx): return
	for unit in battle.units:
		if unit.alive and unit.die_t < 0 and int(unit.owner) == owner: _apply_tech_bonuses(unit)
	if owner == battle.player_owner: ports._feedback("研究完成：%s" % str(tech_row(idx).get("name", "?")))
	print("TECH: owner%d completed %d 「%s」 %s" % [owner,idx,str(tech_row(idx).get("name", "?")),str(state)])

func _cancel_tech() -> bool:
	var job := _research_for_building(_selected_research_building())
	if not job.is_empty():
		battle.economy.refund(int(job.owner),job.cost); battle.research_jobs.erase(job)
		ports._feedback("已取消研究，返还75%费用"); return true
	if not battle.tech_progress.is_empty():
		battle.economy.refund(battle.player_owner,battle.tech_progress.get("cost",{})); battle.tech_progress = {}
		return true
	return false

func _display_research() -> Dictionary:
	var job := _research_for_building(_selected_research_building())
	return job if not job.is_empty() else battle.tech_progress

func tech_research_active() -> bool:
	return not _display_research().is_empty()

func tech_research_name() -> String:
	return str(tech_row(int(_display_research().get("tech",-1))).get("name",""))

func tech_research_remaining() -> int:
	var job := _display_research()
	return maxi(0,Config.TECH_TICKS-int(job.get("t",0))) if not job.is_empty() else 0

func _is_water_unit(u: Dictionary) -> bool:
	return int(u.get("unit", -1)) in Config.TECH_WATER_UNITS

func _is_melee_unit(u: Dictionary) -> bool:
	if bool(u.get("is_building", false)) or _is_worker_unit(u) or _is_water_unit(u):
		return false
	return int(u.get("unit", -1)) in Config.TECH_MELEE_UNITS

func _apply_tech_bonuses(u: Dictionary) -> void:
	var owner := int(u.get("owner", -1))
	if owner <= 0: return
	var state := _tech_for(owner)
	if not u.has("base_maxhp"):
		u["base_maxhp"] = float(u.get("maxhp", 0.0))
	var base_max := float(u.get("base_maxhp", 0.0))
	var level := int(state.get("level", 0))
	if bool(u.get("is_building", false)):
		if int(u.unit) < 27 and int(u.unit) not in [18, 19]:
			var want_max := base_max + 400.0 * level
			u["maxhp"] = want_max
			u["hp"] = clampf(float(u.get("hp", 0.0)), 0.0, want_max)
	elif int(u.unit) in Config.MOBILE_HP_UNITS:
		var applied := int(u.get("tech_hp_bonus", 0))
		var want_hp := 400 * level
		var delta := want_hp - applied
		# 原版只把“当前 HP”+400；最大 HP 仍取类型基础值（可超过上限，界面按当前值显示）。
		u["maxhp"] = base_max
		if delta != 0:
			u["hp"] = maxf(0.0, float(u.get("hp", 0.0)) + float(delta))
			u["tech_hp_bonus"] = want_hp
	# 四列效果按兵种档位取值；武将计算器只使用武力与品级，不套普通兵种加成。
	u["attack_bonus"] = 0.0
	u["attack_b_bonus"] = 0.0
	u["defence_bonus"] = 0.0
	u["defence_b_bonus"] = 0.0
	if preload("res://simulation/systems/combat_rules.gd").hero(u): return
	var category := _combat_tech_category(int(u.unit))
	if category >= 0:
		u.attack_bonus = _combat_tech_value("weapon", 6, category, owner)
		u.attack_b_bonus = _combat_tech_value("bow", 3, category, owner)
		u.defence_bonus = _combat_tech_value("armor", 9, category, owner)
		u.defence_b_bonus = u.defence_bonus
	if int(u.unit) in [34,47]:
		# 两类均没有普通家族档位，按用户补充与现有规格的槽−1规则读取各研究列。
		u.attack_bonus = 0.0
		u.attack_b_bonus = _catapult_tech_value(owner) if int(u.unit) == 34 else _combat_tech_value("weapon", 6, 3, owner)
		u.defence_bonus = _combat_tech_value("bow", 3, 3, owner)
		u.defence_b_bonus = _combat_tech_value("armor", 9, 3, owner)
	if _is_water_unit(u):
		# 水军专用研究位只替换B攻击与两种防御；A攻击仍走普通兵种档位。
		var ship_level := int(state.get("ship_atk", 0))
		var armored := int(state.get("ship_def", 0)) > 0
		match int(u.unit):
			46:
				u.attack_b_bonus = float(Config.TECH_TABLE[20].v[4]) if ship_level >= 1 else 0.0
				u.defence_bonus = float(Config.TECH_TABLE[22].v[4]) if armored else 0.0
			48:
				u.attack_b_bonus = float(Config.TECH_TABLE[21].v[4]) if ship_level >= 2 else 0.0
				u.defence_bonus = float(Config.TECH_TABLE[22].v[5]) if armored else 0.0
			49:
				# 用户确认的相邻字段规则：连船B攻取投石车研究，防取战船研究。
				u.attack_b_bonus = _catapult_tech_value(owner)
				u.defence_bonus = float(Config.TECH_TABLE[21].v[4]) if ship_level >= 2 else 0.0
		u.defence_b_bonus = u.defence_bonus

func _catapult_tech_value(owner := -1) -> float:
	if owner < 0: owner = battle.player_owner
	var level := clampi(int(_tech_for(owner).get("catapult", 0)), 0, 2)
	return float(Config.TECH_TABLE[17+level].v[4]) if level > 0 else 0.0

func _combat_tech_category(unit_id: int) -> int:
	if unit_id in [32,36,45,46]: return 0
	if unit_id in [37,38,39,48]: return 1
	if unit_id in [40,41,42]: return 2
	if unit_id in [43,44]: return 3
	return -1

func _combat_tech_value(key: String, first_row: int, category: int, owner := -1) -> float:
	if owner < 0: owner = battle.player_owner
	var level := clampi(int(_tech_for(owner).get(key, 0)), 0, 3)
	if level == 0: return 0.0
	var raw := int(Config.TECH_TABLE[first_row + level - 1].v[4 + category]) & 255
	return float(raw - 256 if raw >= 128 else raw)
