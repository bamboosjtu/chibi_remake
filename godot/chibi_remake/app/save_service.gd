extends RefCounted
# 存档 / 读档编排（ARCH-006 第二步：从 main.gd 抽出来）
#
# 与 ai.gd 相同的**鸭子类型宿主**模式：宿主（main.gd，Node2D）提供
#   units / trainings / gold / wood / food / stone / next_uid / game_end
# 以及 `_spawn_unit()` / `_free_unit_at()` / `_officer_by_index()` 三个钩子，
# 本模块只负责"把存档记录写回世界状态"的编排，不碰渲染细节。
#
# 四条硬约束（ARCH-001 / ARCH-002）：
#   1. `uid` 按存档写回，**不重新分配** —— 否则身份漂移，训练出来的兵会对错人
#   2. `next_uid` 一并恢复 —— 否则新单位会撞上旧 uid
#   3. **完整快照语义**：快照里没点名的地图对象 = 已阵亡并被 `_prune_dead` 清理 → 必须移除，
#      否则读档会把它们"复活"
#   4. 任何失败都必须 push_warning / print，**不许静默**（B2 的老毛病）
#
# v3 = 具名字段 + 完整快照；v1（4 字段数组）/ v2（10 字段数组）旧档仍可读。

var host: Object
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")
const TechnologyState = preload("res://simulation/systems/technology_state.gd")

func _init(h: Object) -> void:
	host = h

# ------------------------------------------------------------------- load ----
func apply() -> bool:
	var d := Game.load_save(Game.pending_load_slot)
	return apply_snapshot(d)

func apply_snapshot(d: Dictionary) -> bool:
	if d.is_empty():
		push_warning("load save: 存档为空或无法解析")
		return false
	if str(d.get("map", "")) != str(host.map_id):
		return false
	var arr = d.get("units", null)
	if not (arr is Array):
		push_warning("load save: 存档里没有单位数据")
		return false
	var ver := int(d.get("v", 1))
	if ver in [4,5,6,7,8]:
		var applied_v4 := _apply_v4(d, arr)
		if applied_v4:
			if host.player_commands != null: host.player_commands.clear()
			host.commands.world._rebuild_unit_index()   # R13：交换世界后整表重建（含 uid 重编号）
		return applied_v4
	if ver > Game.SAVE_VERSION:
		return false
	return preload("res://app/saves/world_transaction.gd").new().apply_legacy(host,d,arr,ver)

func restore_legacy(d: Dictionary, arr: Array, ver: int) -> bool:
	var applied := 0
	if ver >= 3:
		applied = _apply_v3(d, arr)
	else:
		applied = _apply_legacy(d, arr, ver)
	_restore_resources(d)
	if applied == 0:
		push_warning("load save: %d 条记录一条都没能应用（存档与当前关卡不匹配？）" % arr.size())
	host.commands.world._rebuild_unit_index()
	if applied > 0:
		host.auto_control = false # v1-v3 have no delegation flag.
	return applied > 0

func _apply_v4(d: Dictionary, arr: Array) -> bool:
	var validator = preload("res://app/saves/snapshot_validator.gd").new(host, content_revision, _valid_cost, _valid_integer)
	var plan: Dictionary = validator.prepare(d, arr)
	if plan.is_empty(): return false
	var transaction = preload("res://app/saves/world_transaction.gd").new()
	return transaction.apply(host, d, arr, plan)

func restore_candidate(d: Dictionary, arr: Array, plan: Dictionary) -> bool:
	var restorer = preload("res://app/saves/snapshot_restorer.gd").new(host, _apply_unit_record, _restore_resources, _restore_trainings, _numeric_keys)
	return restorer.restore(d, arr, plan)

func content_revision() -> String:
	var f := FileAccess.open("res://data/%s.json" % str(host.map_id), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var simulation := {}
	for key in ["rows", "cols", "tileW", "terrainW", "terrainH", "walkable", "terrainWalkable", "scenario", "navigation", "units", "objects"]:
		simulation[key] = data.get(key)
	for entry in simulation.units.values():
		entry.erase("sheet")
		entry.erase("sheetK")
	for entry in simulation.objects:
		entry.erase("sheet")
	return ("battle-content-v2:one-based-officers:med-groups:" + JSON.stringify(simulation) + FileAccess.get_sha256("res://data/db/scenario_rules.json")).sha256_text()

func _numeric_keys(value: Dictionary) -> Dictionary:
	var result := {}
	for key in value:
		result[int(key)] = value[key]
	return result

func _apply_v3(d: Dictionary, arr: Array) -> int:
	return preload("res://app/saves/legacy_snapshot.gd").new(host, _apply_unit_record, _restore_trainings)._apply_v3(d, arr)
func _apply_legacy(d: Dictionary, arr: Array, ver: int) -> int:
	return preload("res://app/saves/legacy_snapshot.gd").new(host, _apply_unit_record, _restore_trainings)._apply_legacy(d, arr, ver)
func _apply_unit_record(u: Dictionary, rec: Dictionary) -> void:
	u.ax = float(rec.get("x", u.ax))
	u.ay = float(rec.get("y", u.ay))
	u.hp = maxf(0.0, float(rec.get("hp", u.maxhp)))
	u.alive = bool(rec.get("alive", true)) and (u.hp > 0.0 or bool(rec.get("simulation", {}).get("site", false)))
	u.state = str(rec.get("state", "idle")) if u.alive else "dead"
	u.target = null
	u.path = []
	u.pi = 0
	# ARCH-001：淡出中的对象也要保留死亡进度，否则读档后会重新获得行动能力
	u.die_t = float(rec.get("dieT", -1.0)) if u.alive else -1.0
	if u.alive and u.die_t >= 0.0:
		u.state = "dead"
	# ARCH-008：武将身份按索引恢复（不再靠排序位置重新分配）
	var oi := int(rec.get("officerIndex", -1))
	u["officer"] = {}
	if oi >= 0:
		var o: Dictionary = host.commands.military._officer_by_index(oi)
		if not o.is_empty():
			u["officer"] = o
			u["officer_might"] = float(o.get("might", 0))
			u["officer_intellect"] = float(o.get("intellect", 0))
	host.commands.world._place_unit(u)            # 表现层 + R13 占格索引（视图缺席时也同步索引）
	if host.view != null:
		host.view.unit_nodes(u).spr.visible = u.alive
		host.view.unit_nodes(u).spr.modulate = Color(1, 1, 1, maxf(0.0, 1.0 - maxf(0.0, u.die_t) * 0.55))
		if not u.alive:
			host.view.unit_nodes(u).hbar.visible = false

func _restore_resources(d: Dictionary) -> void:
	var res = d.get("resources", null)
	if res is Dictionary:
		host.gold = float(res.get("gold", host.gold))
		host.wood = float(res.get("wood", host.wood))
		host.food = float(res.get("food", host.food))
		host.stone = float(res.get("stone", host.stone))

## ARCH-002：生产队列也恢复（队列在 `_start_train` 时已经扣过费）
func _restore_trainings(d: Dictionary) -> void:
	var tlist: Array = host.trainings
	tlist.clear()
	var arr = d.get("trainings", null)
	if not (arr is Array):
		return
	var by_uid := {}
	for u in host.units:
		by_uid[int(u.uid)] = u
	for rec in arr:
		if not (rec is Dictionary):
			continue
		var b: Dictionary = by_uid.get(int(rec.get("buildingUid", -1)), {})
		if b.is_empty():
			continue                      # 生产建筑已不存在 → 丢弃该队列项
		tlist.append({
			"owner": int(rec.get("owner", b.owner)),
			"b": b, "unit": int(rec.get("unit", -1)),
			"t": float(rec.get("t", 0.0)) if bool(rec.get("ticks", false)) else ceilf(float(rec.get("t", 0.0)) / host.SIM_DT), "cost": rec.get("cost", {}), "ticks": true,
		})
		for field in ["aiSlot","aiToken","navalSlot","navalToken"]:
			if rec.has(field): tlist.back()[field]=int(rec[field])

func _valid_cost(value: Variant) -> bool:
	if not value is Dictionary: return false
	for kind in ["gold","wood","food","stone"]:
		var amount = value.get(kind, 0)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0: return false
	return true

func _valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))

# ------------------------------------------------------------------- save ----
## 存档的"额外字段"（main.gd 的 `_save_extra()` 转发到这里）
func save_extra() -> Dictionary:
	host.transports.reconcile()
	var decor := {}
	for key in host.decor_cells:
		var target: Dictionary = host.decor_cells[key]
		if int(target.unit) in [100,102,104]: decor[key] = {"stock": float(target.get("stock", 0))}
	var extra := {"nextUid": int(host.next_uid), "trainings": host.trainings, "gameEnd": int(host.game_end), "simulation": {
		"rngState": str(host.simulation_rng.state), "contentRevision": content_revision(), "tick": host.sim_tick, "accumulator": host.sim_acc, "speedIndex": host.clock.speed_index,
		"explored": host.visibility.snapshot(), "projectiles":host.projectiles.snapshot(), "fireFields":host.fire_fields.snapshot(), "decorResources": decor,
		"aiResources": host.ai_res, "groups": host.control_groups,
		"taskLatches": host.task_latches, "officerProgress": host.officer_progress, "terrainChanges": host.terrain_changes, "taskEvents": host.task_events, "objectiveDone": host.objective_done,
		"officerPool": host.commands.military._officer_pool_state(),
		# 科技树：等级表（player_tech）与进行中的研究（tech_progress，含已扣费用以便取消返还）。
		"playerTech": host.player_tech.duplicate(true),
		"armyTech": host.army_tech.duplicate(true),
		"techProgress": host.tech_progress.duplicate(true),
		"researchJobs": host.research_jobs.duplicate(true),
		"ai": host.ai.snapshot() if host.ai != null else {},
	}}
	if host.auto_control: extra.simulation["autoControl"] = true
	return extra
