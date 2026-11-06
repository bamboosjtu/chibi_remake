extends RefCounted
## Populate an isolated candidate. The live scene remains untouched on failure.
var host: Object
var _apply_unit_record: Callable
var _restore_resources: Callable
var _restore_trainings: Callable
var _numeric_keys: Callable
const ActionClock = preload("res://simulation/systems/action_clock.gd")
const TickTimers = preload("res://simulation/systems/tick_timers.gd")

func _init(battle: Object, record: Callable, resources: Callable, trainings: Callable, keys: Callable) -> void:
	host = battle
	_apply_unit_record = record
	_restore_resources = resources
	_restore_trainings = trainings
	_numeric_keys = keys

func restore(d: Dictionary, arr: Array, plan: Dictionary) -> bool:
	var simulation: Dictionary = plan.simulation
	var ids: Dictionary = plan.ids
	var speed: int = int(plan.speed)
	var decor_snapshot: Dictionary = plan.decor
	# ---- 校验通过：开始交换世界 ----
	# R07：待确认的施法/单挑引用属于旧世界，恢复后不能保留为可执行状态。
	host.commands.military._reset_jimou()
	host.duel_pending = false
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
	host.next_uid = 0
	var by_uid := {}
	for rec in arr:
		if not host.commands.world._spawn_unit(int(rec.unit), int(rec.owner), float(rec.x), float(rec.y), true):
			push_error("Snapshot unit failed after validation")
			return false
		var u: Dictionary = host.units.back()
		u.uid = int(rec.uid)
		u.map_object = bool(rec.get("mapObject", false))
		u["map_index"] = int(rec.get("mapIndex", -1))
		var state: Dictionary = rec.simulation
		u.maxhp = float(state.get("maxhp", u.maxhp))
		_apply_unit_record.call(u, rec)
		for key in preload("res://app/saves/snapshot_fields.gd").restore_fields():
			if state.get(key) != null:
				# `stock`/`stock_max` 只存在于资源物件（地图对象）—— 读档时单位是新建的普通单位，
				# 没有该键（typeof = TYPE_NIL）；type_convert(x, TYPE_NIL) 会把它变成 null，
				# 之后采集结算 float(null) 直接报错。这里按"原值写回"处理。
				var want := typeof(u.get(key))
				u[key] = state[key] if want == TYPE_NIL else type_convert(state[key], want)
		u.path = []
		for point in state.get("path", []):
			u.path.append(Vector2(float(point[0]), float(point[1])))
		u.pi = int(state.get("pi", 0))
		TickTimers.restore(state, int(d.v), u)
		host.stratagems.restore(state,u)
		ActionClock.restore(state,u)
		preload("res://simulation/systems/locomotion.gd").restore(state,u)
		if host.view != null and bool(u.get("attached",false)):
			host.view.set_unit_attached(u,true) # 暂停读档也立即隐藏载员，不等下一次模拟更新。
		if host.view != null and int(u.get("site_inside_uid", -1)) >= 0: host.commands.world._update_visual(u)
		if not state.has("gather_ticks"): u.gather_ticks = int(round(float(u.gather_t) / host.SIM_DT))
		by_uid[int(u.uid)] = u
	# 所有实体建好后再解析引用，采矿／卸货目标可以排在工人后面。
	for rec in arr:
		var u: Dictionary = by_uid[int(rec.uid)]
		u.target = by_uid.get(int(rec.simulation.get("targetUid", -1)))
		for field in ["build_target", "repair_target", "board_target"]:
			u[field] = by_uid.get(int(rec.simulation.get(field + "Uid", -1)))
		var reference: Dictionary = rec.simulation.get("gatherRef", {})
		if str(reference.get("kind", "")) == "decor":
			u.gather_obj = host.decor_cells.get(str(reference.get("cell", "")))
		elif str(reference.get("kind", "")) == "unit":
			u.gather_obj = by_uid.get(int(reference.get("uid", -1)))
		elif str(reference.get("kind", "")) == "spent":
			u.gather_obj = {"unit":int(reference.unit),"ax":float(reference.x),"ay":float(reference.y),"alive":false,"die_t":0.0}
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
	host.ai_res = _numeric_keys.call(simulation.get("aiResources", {}))
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
	host.tech_progress = {}
	var tp = simulation.get("techProgress", {})
	if tp is Dictionary and not (tp as Dictionary).is_empty():
		host.tech_progress = {
			"tech": int((tp as Dictionary).get("tech", -1)),
			"t": float((tp as Dictionary).get("t", 0.0)),
			"cost": (tp as Dictionary).get("cost", {}),
		}
	if host.ai != null:
		host.ai.restore(simulation.get("ai", {}))
	host.nav.setup(host.map_data)
	host.nav.rebuild_buildings(host.units)
	# R02：读档重建的占地必须与新建一致；旧档若把单位留在建筑占地里，这里按重建后的
	# 真实阻挡把它们挪到最近可走格，避免“合法工人被包进帅帐”。
	host.commands.orders._resolve_navigation_overlaps()
	host.transports.restore(int(d.v))
	host.commands.world._update_gates()
	host.visibility.restore(str(simulation.get("explored", "")), host.units, host.player_owner)
	if host.view != null and host.view.event_view != null:
		host.view.capture_motion()
		host.view.event_view.restore_history()
		for unit in host.units:
			if unit.alive and float(unit.die_t)<0: host.commands.world._update_visual(unit)
		if host.view.completion != null:
			host.view.completion.reset()
			host.view.end_label.hide()
			if host.game_end != 0: host.view.show_end(host.game_end)
		host.view.projectile_view.impacts.clear()
	return true

func _restore_clock(simulation: Dictionary, speed: int) -> void:
	host.clock.set_speed(int(speed))
	host.sim_tick = int(simulation.get("tick", 0))
	if simulation.has("rngState"):host.simulation_rng.state = int(str(simulation.rngState))
	host.sim_acc = float(simulation.get("accumulator", 0))
	if not simulation.has("speedIndex"):
		# 旧版以1/30秒为一个tick；迁移保留已走过的tick比例。
		host.sim_acc *= host.clock.period()/host.SIM_DT
