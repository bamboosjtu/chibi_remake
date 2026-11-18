extends RefCounted
## Populate an isolated candidate. The live scene remains untouched on failure.
var host: Object
var _apply_unit_record: Callable
var _restore_resources: Callable
var _restore_trainings: Callable
var _numeric_keys: Callable
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")
const UnitSchema = preload("res://simulation/definitions/unit_schema.gd")
const Relations = preload("res://app/saves/unit_relations.gd")
const Envelope = preload("res://app/saves/save_envelope.gd")

func _init(battle: Object, record: Callable, resources: Callable, trainings: Callable, keys: Callable) -> void:
	host = battle
	_apply_unit_record = record
	_restore_resources = resources
	_restore_trainings = trainings
	_numeric_keys = keys

func restore(d: Dictionary, arr: Array, plan: Dictionary) -> bool:
	if not Envelope.valid_header(d) or not Envelope.valid_collections(d): return false
	var simulation: Dictionary = plan.simulation
	var ids: Dictionary = plan.ids
	var speed: int = int(plan.speed)
	var decor_snapshot: Dictionary = plan.decor
	# Unit factories must see snapshot technology, never the live world's levels.
	host.player_tech=simulation.get("playerTech",{}).duplicate(true)
	host.army_tech=_numeric_keys.call(simulation.get("armyTech",{})).duplicate(true)
	# ---- 校验通过：开始交换世界 ----
	# R07：待确认的施法/单挑引用属于旧世界，恢复后不能保留为可执行状态。
	host.commands.military._reset_jimou()
	host.duel_pending = false
	host.cmd_pending = ""
	host.cmd_pending_data = {}
	host.commands.economy._build_decor_targets()
	for key in decor_snapshot:
		var entry: Dictionary = decor_snapshot[key]
		var target: Dictionary = host.decor_cells[str(key)]
		target.stock = float(entry.stock)
		if target.stock <= 0: host.commands.economy._remove_decor(target)

	host.commands.military._restore_officer_pool(simulation.get("officerPool", {}))
	host.selected.clear()
	while not host.units.is_empty():
		host.commands.world._free_unit_at(host.units.size() - 1)
	if not _restore_units(d, arr, simulation): return false
	host.next_uid = int(d.nextUid)
	host.commands.military._enforce_team_limits()
	for uid in ids:
		host.next_uid = maxi(host.next_uid, int(uid) + 1)
	host.game_end = int(d.get("gameEnd", 0))
	host.auto_control = bool(simulation.get("autoControl", false))
	_restore_resources.call(d)
	_restore_trainings.call(d)
	host.projectiles.restore(simulation.get("projectiles",[]))
	host.fire_fields.restore(simulation.get("fireFields",[]))
	_restore_clock(simulation, speed)
	host.ai_res = _numeric_keys.call(simulation.get("aiResources", {})).duplicate(true)
	host.control_groups = _numeric_keys.call(simulation.get("groups", {}))
	for key in host.control_groups:
		host.control_groups[key]=host.control_groups[key].map(func(uid):return int(uid))
	host.task_latches = simulation.get("taskLatches", {}).duplicate(true)
	host.officer_progress = _numeric_keys.call(simulation.get("officerProgress", {}))
	host.terrain_changes = simulation.get("terrainChanges", {}).duplicate(true)
	host.map_data["terrainWalkable"] = host.terrain_base.duplicate()
	for key in host.terrain_changes:
		var cell: PackedStringArray = str(key).split("/")
		host.map_data.terrainWalkable[int(cell[1]) * int(host.map_data.cols) + int(cell[2])] = 1
	host.task_events = simulation.get("taskEvents", []).duplicate(true)
	host.objective_done = bool(simulation.get("objectiveDone", false))
	# 科技树：等级表与研究队列（数值化，避免 JSON 的 float/int 混型）。
	# 科技使用level/bow/weapon等具名键，不能按势力表把字符串键转成整数0。
	host.player_tech = simulation.get("playerTech", {}).duplicate(true)
	host.army_tech = _numeric_keys.call(simulation.get("armyTech", {})).duplicate(true)
	# 攻防加成是科技等级的派生数据；旧档的单口径缓存不能覆盖新四计算器。
	for unit in host.units:
		host.commands.technology._apply_tech_bonuses(unit)
	host.research_jobs = simulation.get("researchJobs",[]).duplicate(true)
	if host.ai != null:
		host.ai.restore(simulation.get("ai", {}))
	# rebuild_buildings performs the terrain reset and preserves resource cells.
	host.nav.set_resources(host.decor_targets)
	host.nav.rebuild_buildings(host.units)
	# R02：读档重建的占地必须与新建一致；旧档若把单位留在建筑占地里，这里按重建后的
	# 真实阻挡把它们挪到最近可走格，避免“合法工人被包进帅帐”。
	host.commands.orders._resolve_navigation_overlaps()
	host.transports.restore()
	host.commands.world._update_gates()
	host.visibility.restore(str(simulation.get("explored", "")), host.units, host.player_owner)
	_refresh_view()
	return true

func _restore_scalars(unit: Dictionary, record: Dictionary, state: Dictionary) -> void:
	unit.maxhp = float(state.maxhp)
	_apply_unit_record.call(unit,record)
	UnitSchema.restore_scalars(state,unit)

func _restore_clock(simulation: Dictionary, speed: int) -> void:
	host.clock.set_speed(speed)
	host.sim_tick = int(simulation.tick)
	host.simulation_rng.state = int(simulation.rngState)
	host.sim_acc = float(simulation.accumulator)

func _restore_units(d: Dictionary, arr: Array, simulation: Dictionary) -> bool:
	host.next_uid = 0
	var by_uid := {}
	for rec in arr:
		if not host.commands.world._spawn_unit(int(rec.unit), int(rec.owner), float(rec.x), float(rec.y), true):
			push_error("Snapshot unit failed after validation")
			return false
		var u: Dictionary = host.units.back()
		u.uid = int(UnitSchema.record_value(rec, "uid"))
		u.map_object = bool(UnitSchema.record_value(rec, "map_object", false))
		u["map_index"] = int(UnitSchema.record_value(rec, "map_index", -1))
		var state: Dictionary = rec.simulation
		_restore_scalars(u,rec,state)
		TickTimers.restore(state,u)
		host.stratagems.restore(state,u)
		ActionClock.restore(state,u)
		preload("res://simulation/systems/locomotion.gd").restore(state,u)
		if host.view != null and bool(u.get("attached",false)):
			host.view.set_unit_attached(u,true) # 暂停读档也立即隐藏载员，不等下一次模拟更新。
		if host.view != null and int(u.get("site_inside_uid", -1)) >= 0: host.commands.world._update_visual(u)
		by_uid[int(u.uid)] = u
	# 所有实体建好后再解析引用，采矿／卸货目标可以排在工人后面。
	for rec in arr:
		var u: Dictionary = by_uid[int(rec.uid)]
		if not by_uid.has(int(u.get("join_target_uid",-1))): u.join_target_uid = -1
		Relations.restore(u, rec.simulation, by_uid, host.decor_cells)
	return true

func _refresh_view() -> void:
	if host.view != null: host.view.finish_loaded_world(host.units,host.game_end)
