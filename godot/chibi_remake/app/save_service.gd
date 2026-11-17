extends RefCounted
## Validate a current-format archive, then atomically install its candidate world.
var host: Object
var last_load_error := ""
var last_load_source := "none"
var _content_revision_cache := ""
const UnitSchema = preload("res://simulation/definitions/unit_schema.gd")
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")
const TechnologyState = preload("res://simulation/systems/technology_state.gd")

func _init(h: Object) -> void:
	host = h

# ------------------------------------------------------------------- load ----
func apply() -> bool:
	var loaded: Dictionary = Game.repository.read_slot(Game.pending_load_slot)
	var applied := apply_snapshot(loaded.data)
	last_load_source = loaded.source if applied else "none"
	if applied and last_load_source == "backup": host.commands.world._feedback("主记录无法读取，已从备份恢复进度。")
	return applied

func apply_snapshot(d: Dictionary) -> bool:
	last_load_error = ""
	last_load_source = "none"
	var applied := _apply_snapshot(d)
	if not applied and last_load_error.is_empty(): last_load_error = "快照恢复或画面重建失败，当前战场未改变。"
	return applied

func _apply_snapshot(d: Dictionary) -> bool:
	if d.is_empty():
		last_load_error = "进度为空、校验失败或无法读取。"
		push_warning("load save: 存档为空或无法解析")
		return false
	var envelope = preload("res://app/saves/save_envelope.gd")
	if d.get("v") != preload("res://app/saves/save_format.gd").VERSION:
		last_load_error = "仅支持当前 v9 存档；旧版本不再迁移，当前战场已保留。"
		return false
	if not envelope.valid_header(d) or not envelope.valid_collections(d):
		last_load_error = "存档头部、资源或生产队列字段不兼容；当前战场已保留。"
		return false
	if str(d.get("map", "")) != str(host.map_id):
		last_load_error = "存档关卡与当前战场不匹配。"
		return false
	var arr = d.get("units", null)
	if not (arr is Array):
		last_load_error = "进度缺少有效的单位列表。"
		push_warning("load save: 存档里没有单位数据")
		return false
	var applied := _restore_current(d,arr)
	if applied:
		host.player_commands.clear()
		host.commands.world._rebuild_unit_index()
	return applied

func _restore_current(d: Dictionary, arr: Array) -> bool:
	var validator = preload("res://app/saves/snapshot_validator.gd").new(host, content_revision, _valid_cost, _valid_integer)
	var plan: Dictionary = validator.prepare(d, arr)
	if plan.is_empty():
		last_load_error = validator.compatibility_error if not validator.compatibility_error.is_empty() else "存档内容版本、字段或对象引用不兼容；当前战场已保留。"
		return false
	var transaction = preload("res://app/saves/world_transaction.gd").new()
	return transaction.apply(host, d, arr, plan)

func restore_candidate(d: Dictionary, arr: Array, plan: Dictionary) -> bool:
	var restorer = preload("res://app/saves/snapshot_restorer.gd").new(host, _apply_unit_record, _restore_resources, _restore_trainings, _numeric_keys)
	return restorer.restore(d, arr, plan)

func content_revision() -> String:
	if _content_revision_cache.is_empty():
		var data: Dictionary=host.world.definition.duplicate(true)
		var projection:=_map_projection(data)
		_content_revision_cache=("battle-content-v3:"+preload("res://app/saves/rules_identity.gd").catalog_hash(JSON.stringify(projection))).sha256_text()
	return _content_revision_cache

func _map_projection(data: Dictionary) -> Dictionary:
	var simulation := {}
	for key in ["rows","cols","tileW","terrainW","terrainH","walkable","terrainWalkable","scenario","navigation","units","objects","waterWalkable","decor"]:
		simulation[key] = data.get(key)
	for entry in simulation.units.values():
		entry.erase("sheet"); entry.erase("sheetK")
	if simulation.objects == null: simulation.objects = []
	for entry in simulation.objects: entry.erase("sheet")
	return simulation

func _numeric_keys(value: Dictionary) -> Dictionary:
	var result := {}
	for key in value:
		result[int(key)] = value[key]
	return result

func _apply_unit_record(u: Dictionary, rec: Dictionary) -> void:
	var anchor := Vector2(float(UnitSchema.record_value(rec,"ax",u.ax)),float(UnitSchema.record_value(rec,"ay",u.ay)))
	u.ax = anchor.x
	u.ay = anchor.y
	var cell: Vector2i=host.nav.cell_of_px(u.ax,u.ay)
	u.A=cell.x;u.B=cell.y
	var dying := float(UnitSchema.record_value(rec, "die_t", -1.0)) >= 0.0
	var recorded_alive := bool(UnitSchema.record_value(rec, "alive", true))
	var recorded_hp := float(UnitSchema.record_value(rec, "hp", u.maxhp))
	u.hp = recorded_hp if dying or not recorded_alive else maxf(0.0,recorded_hp)
	u.alive = recorded_alive and (u.hp > 0.0 or dying or bool(rec.get("simulation", {}).get("site", false)))
	u.state = str(UnitSchema.record_value(rec, "state", "idle")) if u.alive else "dead"
	u.target = null
	u.path = []
	u.pi = 0
	# ARCH-001：淡出中的对象也要保留死亡进度，否则读档后会重新获得行动能力
	u.die_t = float(UnitSchema.record_value(rec, "die_t", -1.0)) if u.alive else -1.0
	if u.alive and u.die_t >= 0.0:
		u.state = "dead"
	# ARCH-008：武将身份按索引恢复（不再靠排序位置重新分配）
	var oi := int(UnitSchema.record_value(rec, "officer", -1))
	u["officer"] = {}
	if oi >= 0:
		var o: Dictionary = host.commands.military._officer_by_index(oi)
		if not o.is_empty():
			u["officer"] = o
			u["officer_might"] = float(o.get("might", 0))
			u["officer_intellect"] = float(o.get("intellect", 0))
	host.commands.world._place_unit(u)            # 表现层 + R13 占格索引（视图缺席时也同步索引）
	if host.view != null:
		host.view.apply_loaded_unit(u)

func _restore_resources(d: Dictionary) -> void:
	for key in preload("res://app/saves/save_envelope.gd").RESOURCE_KEYS: host.set(key,float(d.resources[key]))

func _restore_trainings(d: Dictionary) -> void:
	var by_uid := {}
	for unit in host.units: by_uid[int(unit.uid)] = unit
	host.trainings.clear()
	for record in d.trainings:
		var order := {"owner":int(record.owner),"b":by_uid[int(record.buildingUid)],"unit":int(record.unit),"t":float(record.t),"cost":record.cost.duplicate(true),"ticks":true}
		for field in ["aiSlot","aiToken","navalSlot","navalToken"]:
			if record.has(field): order[field] = int(record[field])
		host.trainings.append(order)

func _valid_cost(value: Variant) -> bool:
	return preload("res://simulation/definitions/resource_cost.gd").valid(value)

func _valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))

# ------------------------------------------------------------------- save ----
## 存档的"额外字段"（main.gd 的 `_save_extra()` 转发到这里）
func save_extra(reconcile := true) -> Dictionary:
	if reconcile: host.transports.reconcile()
	var decor := {}
	for key in host.decor_cells:
		var target: Dictionary = host.decor_cells[key]
		if int(target.unit) in [100,102,104]: decor[key] = {"stock": float(target.get("stock", 0))}
	var extra := {"nextUid": int(host.next_uid), "trainings": host.trainings, "gameEnd": int(host.game_end), "simulation": {
		"rngState": str(host.simulation_rng.state), "contentRevision": content_revision(), "rulesRevision":preload("res://app/saves/rules_identity.gd").current(), "tick": host.sim_tick, "accumulator": host.sim_acc, "speedIndex": host.clock.speed_index,
		"explored": host.visibility.snapshot(), "projectiles":host.projectiles.snapshot(), "fireFields":host.fire_fields.snapshot(), "decorResources": decor,
		"aiResources": host.ai_res, "groups": host.control_groups,
		"taskLatches": host.task_latches, "officerProgress": host.officer_progress, "terrainChanges": host.terrain_changes, "taskEvents": host.task_events, "objectiveDone": host.objective_done,
		"officerPool": host.commands.military._officer_pool_state(),
		# 科技树：等级表（player_tech）与研究队列。
		"playerTech": host.player_tech.duplicate(true),
		"armyTech": host.army_tech.duplicate(true),
		"researchJobs": host.research_jobs.duplicate(true),
		"ai": host.ai.snapshot() if host.ai != null else {},
	}}
	if host.auto_control: extra.simulation["autoControl"] = true
	extra["pendingDuels"] = host.effects.pending_duels().size()
	return extra

## Supplementary full-state digest; historical simulation baselines stay intact.
func continuation_snapshot(game: Node) -> Dictionary:
	var payload: Dictionary = game.snapshot(host.units,{"gold":host.gold,"wood":host.wood,"food":host.food,"stone":host.stone},save_extra(false))
	for key in ["checksum","savedAt","saveName"]: payload.erase(key)
	payload.simulation.erase("accumulator") # Wall-clock dispatch remainder, not per-tick state.
	var occupied := {}
	for cell in host.nav.state.occupancy:
		if int(host.nav.state.occupancy[cell]) > 0: occupied[cell] = host.nav.state.occupancy[cell]
	payload["navigation"] = {"resources":host.nav.state.resource_cells.duplicate(),"blocked":host.nav.state.blocked_cells.duplicate(),"occupancy":occupied}
	payload["pendingDuels"] = host.effects.duel_snapshot()
	return payload
