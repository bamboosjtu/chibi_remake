extends RefCounted
## Populate an isolated candidate. The live scene remains untouched on failure.
var host: Object
const BattleState = preload("res://simulation/state/battle_state.gd")
var battle: BattleState:
	get: return host.state
var _apply_unit_record: Callable
var _restore_resources: Callable
var _restore_trainings: Callable
var _numeric_keys: Callable
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")
const UnitSchema = preload("res://simulation/units/unit_schema.gd")
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
	battle.player_tech=simulation.get("playerTech",{}).duplicate(true)
	battle.army_tech=_numeric_keys.call(simulation.get("armyTech",{})).duplicate(true)
	# ---- 校验通过：开始交换世界 ----
	# R07：待确认的施法/单挑引用属于旧世界，恢复后不能保留为可执行状态。
	host.world.abilities._reset_jimou()
	battle.duel_pending = false
	battle.cmd_pending = ""
	battle.cmd_pending_data = {}
	host.world.harvest_orders._build_decor_targets()
	for key in decor_snapshot:
		var entry: Dictionary = decor_snapshot[key]
		var target: Dictionary = battle.decor_cells[str(key)]
		target.stock = float(entry.stock)
		if target.stock <= 0: host.world.harvest_orders._remove_decor(target)

	host.world.officer_pool._restore_officer_pool(simulation.get("officerPool", {}))
	battle.selected.clear()
	while not battle.units.is_empty():
		host.world.battle_simulation._free_unit_at(battle.units.size() - 1)
	if not _restore_units(d, arr, simulation): return false
	battle.next_uid = int(d.nextUid)
	host.world.command_groups._enforce_team_limits()
	for uid in ids:
		battle.next_uid = maxi(battle.next_uid, int(uid) + 1)
	battle.game_end = int(d.get("gameEnd", 0))
	battle.auto_control = bool(simulation.get("autoControl", false))
	_restore_resources.call(d)
	_restore_trainings.call(d)
	host.world.projectiles.restore(simulation.get("projectiles",[]))
	host.world.fire_fields.restore(simulation.get("fireFields",[]))
	_restore_clock(simulation, speed)
	battle.ai_res = _numeric_keys.call(simulation.get("aiResources", {})).duplicate(true)
	battle.control_groups = _numeric_keys.call(simulation.get("groups", {}))
	for key in battle.control_groups:
		battle.control_groups[key]=battle.control_groups[key].map(func(uid):return int(uid))
	battle.task_latches = simulation.get("taskLatches", {}).duplicate(true)
	battle.officer_progress = _numeric_keys.call(simulation.get("officerProgress", {}))
	battle.terrain_changes = simulation.get("terrainChanges", {}).duplicate(true)
	battle.map_data["terrainWalkable"] = battle.terrain_base.duplicate()
	for key in battle.terrain_changes:
		var cell: PackedStringArray = str(key).split("/")
		battle.map_data.terrainWalkable[int(cell[1]) * int(battle.map_data.cols) + int(cell[2])] = 1
	battle.task_events = simulation.get("taskEvents", []).duplicate(true)
	battle.objective_done = bool(simulation.get("objectiveDone", false))
	# 科技树：等级表与研究队列（数值化，避免 JSON 的 float/int 混型）。
	# 科技使用level/bow/weapon等具名键，不能按势力表把字符串键转成整数0。
	battle.player_tech = simulation.get("playerTech", {}).duplicate(true)
	battle.army_tech = _numeric_keys.call(simulation.get("armyTech", {})).duplicate(true)
	# 攻防加成是科技等级的派生数据；旧档的单口径缓存不能覆盖新四计算器。
	for unit in battle.units:
		host.world.technology._apply_tech_bonuses(unit)
	battle.research_jobs = simulation.get("researchJobs",[]).duplicate(true)
	if host.world.ai != null:
		host.world.ai.restore(simulation.get("ai", {}))
	# rebuild_buildings performs the terrain reset and preserves resource cells.
	host.world.nav.set_resources(battle.decor_targets)
	host.world.nav.rebuild_buildings(battle.units)
	# R02：读档重建的占地必须与新建一致；旧档若把单位留在建筑占地里，这里按重建后的
	# 真实阻挡把它们挪到最近可走格，避免“合法工人被包进帅帐”。
	host.world.movement._resolve_navigation_overlaps()
	host.world.transports.restore()
	host.world.battle_simulation._update_gates()
	host.world.visibility.restore(str(simulation.get("explored", "")), battle.units, battle.player_owner)
	return true

func _restore_scalars(unit: Dictionary, record: Dictionary, state: Dictionary) -> void:
	unit.maxhp = float(state.maxhp)
	_apply_unit_record.call(unit,record)
	UnitSchema.restore_scalars(state,unit)

func _restore_clock(simulation: Dictionary, speed: int) -> void:
	host.world.clock.set_speed(speed)
	battle.sim_tick = int(simulation.tick)
	battle.simulation_rng.state = int(simulation.rngState)
	battle.sim_acc = float(simulation.accumulator)

func _restore_units(d: Dictionary, arr: Array, simulation: Dictionary) -> bool:
	battle.next_uid = 0
	var by_uid := {}
	for rec in arr:
		if not host.world.entity_factory._spawn_unit(int(rec.unit), int(rec.owner), float(rec.x), float(rec.y), true):
			push_error("Snapshot unit failed after validation")
			return false
		var u: Dictionary = battle.units.back()
		u.uid = int(UnitSchema.record_value(rec, "uid"))
		u.map_object = bool(UnitSchema.record_value(rec, "map_object", false))
		u["map_index"] = int(UnitSchema.record_value(rec, "map_index", -1))
		var state: Dictionary = rec.simulation
		_restore_scalars(u,rec,state)
		TickTimers.restore(state,u)
		host.world.stratagems.restore(state,u)
		ActionClock.restore(state,u)
		preload("res://simulation/systems/locomotion.gd").restore(state,u)
		by_uid[int(u.uid)] = u
	# 所有实体建好后再解析引用，采矿／卸货目标可以排在工人后面。
	for rec in arr:
		var u: Dictionary = by_uid[int(rec.uid)]
		if not by_uid.has(int(u.get("join_target_uid",-1))): u.join_target_uid = -1
		Relations.restore(u, rec.simulation, by_uid, battle.decor_cells)
	return true
