extends RefCounted
## Validate the complete snapshot before constructing or modifying any world.
var host: Node2D
var content_revision: Callable
var _valid_cost: Callable
var _valid_integer: Callable
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")
const TechnologyState = preload("res://simulation/systems/technology_state.gd")

func _init(battle: Node2D, revision: Callable, cost: Callable, integer: Callable) -> void:
	host = battle
	content_revision = revision
	_valid_cost = cost
	_valid_integer = integer

func _valid_control_fields(simulation: Dictionary) -> bool:
	if simulation.has("autoControl") and not simulation.autoControl is bool: return false
	if simulation.has("rngState") and (not simulation.rngState is String or not str(simulation.rngState).is_valid_int()):return false
	return true

func prepare(d: Dictionary, arr: Array) -> Dictionary:
	if not d.get("simulation", {}) is Dictionary or not _valid_cost.call(d.get("resources", {})):
		return {}
	var simulation: Dictionary = d.get("simulation", {})
	if not _valid_control_fields(simulation): return {}
	if str(simulation.get("contentRevision", "")) != content_revision.call():
		var compatible := false
		var registry := FileAccess.open("res://data/db/registry_compatibility.json", FileAccess.READ)
		if registry != null:
			var contract = JSON.parse_string(registry.get_as_text())
			var previous := str(simulation.get("contentRevision", ""))
			compatible = previous != "" and contract is Dictionary and str(contract.get("previous", {}).get(host.map_id, "")) == previous and str(contract.get("current", {}).get(host.map_id, "")) == content_revision.call()
		if not compatible:
			push_warning("存档内容版本与关卡不匹配")
			return {}
	var ids := {}
	if not host.visibility.valid_snapshot(simulation.get("explored", "")):
		return {}
	# 在修改世界前验证完整快照。
	for rec in arr:
		if not rec is Dictionary or not rec.get("simulation") is Dictionary:
			return {}
		var uid := int(rec.get("uid", -1))
		if uid < 0 or ids.has(uid) or not host.map_data.units.has(str(int(rec.get("unit", -1)))):
			return {}
		if host.commands._sheet_ref_for(int(rec.unit), int(rec.get("owner", -1))) == "":
			return {}
		if not rec.has("x") or not rec.has("y") or not is_finite(float(rec.x)) or not is_finite(float(rec.y)):
			return {}
		if not rec.simulation.get("path", []) is Array:
			return {}
		for point in rec.simulation.get("path", []):
			if not point is Array or point.size() != 2:
				return {}
		ids[uid] = rec
	# ---- REQ-002：世界修改前**完整**校验（地形键/编组/资源/武将池/训练队列/采集引用/新字段类型） ----
	var rows_n := int(host.map_data.rows)
	var cols_n := int(host.map_data.cols)
	var tch = simulation.get("terrainChanges", {})
	if not tch is Dictionary:
		return {}
	for key in (tch as Dictionary):
		var cell: PackedStringArray = str(key).split("/")
		if cell.size() != 3 or cell[1] == "" or cell[2] == "":
			return {}
		var ca := int(cell[1])
		var cb := int(cell[2])
		if str(ca) != cell[1] or str(cb) != cell[2] or ca < 0 or cb < 0 or ca >= rows_n or cb >= cols_n:
			return {}
	# aiResources：值=每个势力的 {gold/wood/food/stone: float} 嵌套字典；
	# officerProgress：值=数值。两种形状不同，必须分开校验 ——
	# 此前把两者按同一扁平数值 schema 校验，正式游戏里 aiResources 恒为嵌套字典
	# → 合法存档被整体拒收（REQ-002 引入的读档回归，夹具已钉住）。
	var ai_res = simulation.get("aiResources", {})
	if not ai_res is Dictionary:
		return {}
	for k in (ai_res as Dictionary):
		var rv = (ai_res as Dictionary)[k]
		if not rv is Dictionary:
			return {}
		if not _valid_cost.call(rv): return {}
	var prog = simulation.get("officerProgress", {})
	if not prog is Dictionary:
		return {}
	for k in (prog as Dictionary):
		if not ((prog as Dictionary)[k] is float or (prog as Dictionary)[k] is int):
			return {}
	# control_groups：键=组号（JSON 里是字符串，恢复时 int()），值=该组的 **uid 数组**。
	# 此前与 aiResources 用同一循环、按"值必须是数值"校验 → 只要玩家设过任意编组，
	# 合法存档就会被整体拒收（fixture 已在 test_architecture.gd:64 钉住该缺陷）。
	var groups_c = simulation.get("groups", {})
	if not groups_c is Dictionary:
		return {}
	for k in (groups_c as Dictionary):
		var gv = (groups_c as Dictionary)[k]
		if not gv is Array:
			return {}
		for gu in (gv as Array):
			if not _valid_integer.call(gu) or float(gu)>2147483647:
				return {}
	var pool = simulation.get("officerPool", {})
	if not pool is Dictionary:
		return {}
	for k in (pool as Dictionary):
		var s0 = (pool as Dictionary)[k]
		if not _valid_officer_state(s0): return {}
	var production_buildings := {}
	var tarr = d.get("trainings", null)
	if tarr != null:
		if not tarr is Array:
			return {}
		for rec in (tarr as Array):
			if not rec is Dictionary:
				return {}
			var tr0: Dictionary = rec
			for field in ["buildingUid", "unit"]:
				if not _valid_integer.call(tr0.get(field, -1)): return {}
			var building_uid := int(tr0.buildingUid)
			if not ids.has(building_uid) or production_buildings.has(building_uid) or not host.map_data.units.has(str(int(tr0.unit))): return {}
			var building: Dictionary = ids[building_uid]
			if not bool(building.get("building", false)): return {}
			# 订单归属独立保存，不能擅自按建筑当前归属改写（旧档跨势力生产契约）。
			if not _valid_integer.call(tr0.get("owner", building.owner)): return {}
			production_buildings[building_uid] = true
			if not (tr0.get("t", 0.0) is float or tr0.get("t", 0.0) is int):
				return {}
			if not is_finite(float(tr0.get("t",0))) or float(tr0.get("t",0)) < 0 or not _valid_cost.call(tr0.get("cost",{})): return {}
			if bool(tr0.get("ticks",false)) and float(tr0.get("t",0)) != floorf(float(tr0.get("t",0))): return {}
	if not simulation.get("taskLatches", {}) is Dictionary:
		return {}
	if not simulation.get("taskEvents", []) is Array:
		return {}
	# 科技树：player_tech 的每个值必须是数字；tech_progress 若存在必须是合法记录。
	if not TechnologyState.valid(simulation.get("playerTech", {})): return {}
	var army_tech = simulation.get("armyTech", {})
	if not army_tech is Dictionary: return {}
	for key in army_tech:
		if not str(key).is_valid_int() or str(int(key)) != str(key): return {}
		var owner := int(key)
		if owner <= 0 or owner == host.player_owner: return {}
		if host.scenario_sides.all(func(side): return int(side.owner) != owner) and arr.all(func(unit): return int(unit.owner) != owner): return {}
		if not TechnologyState.valid(army_tech[key]): return {}
	var tech_prog = simulation.get("techProgress", null)
	if tech_prog != null:
		if not tech_prog is Dictionary:
			return {}
		# 空字典＝当前没有研究（合法）；非空则必须指向一条合法科技。
		if not (tech_prog as Dictionary).is_empty():
			var research = tech_prog.get("tech", -1)
			var elapsed = tech_prog.get("t", 0)
			if not (research is int or research is float) or not is_finite(float(research)) or float(research) != floorf(float(research)) or float(research) < 0 or float(research) >= host.TECH_TABLE.size(): return {}
			if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or float(elapsed) < 0 or float(elapsed) >= host.TECH_TICKS or float(elapsed) != floorf(float(elapsed)): return {}
			if not _valid_cost.call(tech_prog.get("cost", {})): return {}
	var jobs = simulation.get("researchJobs",[])
	if not jobs is Array: return {}
	var researching := {}
	for job in jobs:
		if not job is Dictionary: return {}
		for field in ["buildingUid","owner","tech","t"]:
			if not _valid_integer.call(job.get(field,-1)): return {}
		var uid := int(job.buildingUid); var owner := int(job.owner); var idx := int(job.tech)
		if owner <= 0 or not ids.has(uid) or production_buildings.has(uid) or int(job.t) >= host.TECH_TICKS or idx >= host.TECH_TABLE.size(): return {}
		var building: Dictionary = ids[uid]
		if not bool(building.get("building",false)) or int(building.owner) != owner or not bool(building.get("alive",false)) or float(building.get("dieT",-1)) >= 0 or bool(building.get("simulation",{}).get("site",false)): return {}
		var line: String = host.commands._tech_line_of(idx)
		var lines: Array = host.TECH_BUILDING_LINES.get(int(building.unit),[])
		if owner != host.player_owner and int(building.unit) in [4,5]: lines = ["bow"]
		if not lines.has(line) or not _valid_cost.call(job.get("cost",{})): return {}
		var key := "%d/%d" % [owner,idx]
		if not host.commands.tech_is_sell(idx) and researching.has(key): return {}
		researching[key] = true; production_buildings[uid] = true
	for rec2 in arr:
		if not rec2 is Dictionary:
			return {}
		var st2: Dictionary = rec2.get("simulation", {})
		if not TickTimers.valid_snapshot(st2, int(d.v)) or not ActionClock.valid_snapshot(st2): return {}
		if not preload("res://simulation/systems/locomotion.gd").valid_snapshot(st2): return {}
		if not host.stratagems.valid_snapshot(st2):return {}
		# R01：统一“基础上限 + 科技当前兵力”的合法范围；升级部队 hp > maxhp 是契约内状态。
		# 只约束仍在场的单位：淡出中的尸体允许保留负 HP（击杀结算不夹到 0）。
		if int(d.v) >= 8 and bool(rec2.get("alive", false)) and float(rec2.get("dieT", -1.0)) < 0.0:
			var life = rec2.get("hp", -1)
			var maximum = st2.get("maxhp", life)
			var base_max = st2.get("base_maxhp", maximum)
			var tech_bonus = st2.get("tech_hp_bonus", 0)
			if maximum == null: maximum = life          # 旧档缺省字段曾写为 null
			if base_max == null: base_max = maximum
			if tech_bonus == null: tech_bonus = 0
			if not TechnologyState.valid_hp(life, maximum, base_max, tech_bonus): return {}
		var last = st2.get("last_attacker_uid",-1)
		if not (last is int or last is float) or not is_finite(float(last)) or float(last)!=floorf(float(last)) or float(last)<-1 or float(last)>2147483647: return {}
		var team=st2.get("team_kind")
		if team!=null and team not in ["","worker","combat"]:return {}
		for key in ["group_officer", "carry", "gather_t", "gather_ticks", "delivery_ticks", "tech_hp_bonus", "mou", "formation", "haste_t", "slow_t", "farsight_t", "confused_t", "burn_t", "burn_dps"]:
			var v1 = st2.get(key, null)
			if v1 != null and (not (v1 is float or v1 is int) or not is_finite(float(v1))):
				return {}
		var paid = st2.get("build_cost", {})
		if paid != null and not _valid_cost.call(paid): return {}
		var join_uid = st2.get("join_target_uid", -1)
		if join_uid != null and (not (join_uid is int or join_uid is float) or not is_finite(float(join_uid)) or float(join_uid) != floorf(float(join_uid)) or float(join_uid) < -1): return {}
		for field in ["build_targetUid", "repair_targetUid", "board_targetUid"]:
			var reference = st2.get(field, -1)
			if not (reference is int or reference is float) or not is_finite(float(reference)): return {}
			if float(reference) != floorf(float(reference)) or (int(reference) != -1 and not ids.has(int(reference))): return {}
		var gref = st2.get("gatherRef", null)
		var group := float(st2.get("group_officer", -1))
		if not is_finite(group) or group != floorf(group) or group < -1 or group > 116:
			return {}
		if gref != null:
			if not gref is Dictionary:
				return {}
			var kind := str((gref as Dictionary).get("kind", ""))
			if kind == "decor" and str((gref as Dictionary).get("cell", "")) == "":
				return {}
			if kind == "unit" and int((gref as Dictionary).get("uid", -1)) < 0:
				return {}
			if kind == "spent":
				if int(gref.get("unit",-1)) not in [10,11,22,24,25]: return {}
				for axis in ["x","y"]:
					var coordinate = gref.get(axis)
					if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): return {}
	var decor_snapshot = simulation.get("decorResources", {})
	if not decor_snapshot is Dictionary: return {}
	for key in decor_snapshot:
		var entry = decor_snapshot[key]
		if not entry is Dictionary or not host.decor_cells.has(str(key)): return {}
		var stock = entry.get("stock", -1)
		if not (stock is int or stock is float) or not is_finite(float(stock)) or float(stock) < 0: return {}
		var base: Dictionary = host.decor_cells[str(key)]
		if int(base.unit) in [100,102] and float(stock) > 200: return {}
	if not host.projectiles.valid_snapshot(simulation.get("projectiles",[])): return {}
	if not host.fire_fields.valid_snapshot(simulation.get("fireFields",[])):return {}
	if not host.transports.valid_snapshot(ids,int(d.v)):return {}
	if not host.construction.valid_snapshot(ids): return {}
	if host.ai != null and not host.ai.valid_snapshot(simulation.get("ai",{}),ids,d.get("trainings",[]),int(d.get("nextUid",0))): return {}
	var speed = simulation.get("speedIndex",2)
	if not (speed is int or speed is float) or not is_finite(float(speed)) or float(speed)!=floorf(float(speed)) or int(speed)<0 or int(speed)>3: return {}
	var accumulator = simulation.get("accumulator",0)
	if not (accumulator is int or accumulator is float) or not is_finite(float(accumulator)) or float(accumulator)<0: return {}
	return {"simulation": simulation, "ids": ids, "speed": speed, "decor": decor_snapshot}

func _valid_officer_state(value) -> bool:
	if not value is Dictionary: return false
	for key in ["exp", "level"]:
		if not _valid_integer.call(value.get(key, 0)): return false
	if value.has("hasExp") and not value.hasExp is bool: return false
	return bool(value.get("hasExp", true)) or int(value.get("exp", 0)) == 0
