extends Object
const UnitPath = preload("res://simulation/movement/unit_path.gd")
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _economy: RefCounted
var _construction: RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## construction orders: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
var battle: State
var _dep_ai_economy: Object
var _dep_battle_simulation: Object
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_entity_factory: Object
var _dep_harvest_orders: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
var _dep_officer_teams: Object
var _dep_production: Object
var _dep_spatial_index: Object
var _dep_technology: Object

func _init(data: State) -> void:
	battle = data

func building_block_reason(bid: int, owner: int = -1) -> String:
	if owner < 0: owner = battle.player_owner
	var kind := bid - bid % 2 if bid < 20 else bid
	if kind not in [0,2,4,6,8,10,12,14,18,20,23,26]: return "此建筑不可建造"
	if owner == battle.player_owner and battle.cheat_build_any: return ""
	# 每组中任一阵营版本均可；组与组之间为“同时满足”。
	# 第二页箭楼前置尚未逐位证实，继续沿用木材场，避免凭空扩张。
	var prerequisites := {23:[[0,1]],12:[[10,11]],14:[[4,5]],18:[[4,5]],6:[[10,11],[4,5]]}
	var names := {0:"帅帐",10:"粮仓",4:"木材场"}
	var missing := PackedStringArray()
	for need in prerequisites.get(kind,[]):
		var found := false
		for building in battle.units:
			if building.alive and building.die_t<0 and int(building.owner)==owner and not building.get("site",false) and int(building.unit) in need:
				found=true;break
		if not found: missing.append(names[int(need[0])])
	if not missing.is_empty(): return "需先建成"+"、".join(missing)
	return ""

func _order_repair(target: Dictionary, actors = null) -> int:
	if bool(target.get("site", false)):
		return _order_build(target, actors)
	if target.is_empty() or not bool(target.get("alive", false)) or float(target.get("die_t", -1)) >= 0 or bool(target.get("attached", false)) or int(target.get("owner", -1)) != battle.player_owner:
		_effects.feedback("修理对象必须是我方单位或建筑")
		return 0
	var n := 0
	for w in _dep_harvest_orders._selected_workers(actors):
		if not w.alive or w.die_t >= 0.0 or not _dep_technology._is_worker_unit(w):
			continue
		_dep_command_groups._cancel_unit_command(w)
		w["repair_target"] = target
		w["state"] = "repair"
		UnitPath.set_points(w, _dep_interaction_paths._interaction_path(w, target, Config.GATHER_REACH))
		w["pi"] = 0
		n += 1
	if n > 0:
		_effects.feedback("%d 名工人前往修理「%s」" % [n, str(target.get("name", "?"))])
	else:
		_effects.feedback("只有工兵可以修理")
	return n

func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	# 目标可能在工人接令后死亡/上船；执行时重验，不能给淡出中的尸体回血扣款。
	if not bool(w.get("alive", false)) or float(w.get("die_t", -1)) >= 0 or not _dep_technology._is_worker_unit(w): return false
	if not bool(t.get("alive", false)) or float(t.get("die_t", -1)) >= 0 or bool(t.get("attached", false)) or bool(t.get("site", false)) or int(t.get("owner", -1)) != int(w.owner): return false
	if float(t.hp) >= float(t.maxhp): return false
	if not _economy.pay(int(w.owner), Balance.work().repairCost):
		_effects.feedback("修理：资源不足")
		return false
	var before := float(t.get("hp", 0.0))
	var cap := float(t.get("maxhp", before))
	t["hp"] = minf(cap, before + float(Balance.work().repairHp))
	_effects.feedback("修理「%s」：+%d 兵力（%.0f/%.0f）" % [
		str(t.get("name", "?")), int(float(t["hp"]) - before), float(t["hp"]), cap])

	return true

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	var origin := Vector2(float(unit.ax), float(unit.ay))
	if future_cells.is_empty() and _dep_interaction_paths._edge_cell_distance(unit, site) == Config.EDGE_DISTANCE:
		return [origin]
	var candidates: Array = _dep_interaction_paths._edge_neighbors(site, int(unit.uid))
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(_nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(_nav.anchor_of(b.x, b.y)))
	for cell in candidates:
		var target := _nav.anchor_of(cell.x, cell.y)
		var path := _nav.find_path_avoiding(origin, target, true, future_cells, _dep_command_groups._nav_layer(unit), int(unit.owner), int(unit.unit))
		if not path.is_empty() and _nav.cell_of_px(path.back().x, path.back().y) == cell: return path
	return []

func build_placement_at(pos: Vector2, opt: Dictionary, actors = null) -> Dictionary:
	var bid := int(opt.get("unit", -1))
	var cell: Vector2i = _dep_movement._cell_of_px(pos.x, pos.y)
	var point := _nav.anchor_of(cell.x, cell.y)
	var meta: Dictionary = battle.map_data.units.get(str(bid), {})
	var result := {"valid":false, "unit":bid, "anchor":point, "cells":[], "outline":PackedVector2Array(), "reason":"地形不对，无法建造"}
	if meta.is_empty(): return result
	if battle.game_end != 0 or not battle.build_types.any(func(entry): return int(entry.unit) == bid): return result
	if _dep_production._army_count(battle.player_owner) >= Balance.army_cap(): result.reason = "已达%d单位上限" % Balance.army_cap(); return result
	var cells := _nav.building_footprint(bid, point, float(meta.w))
	result.cells = cells
	result.outline = _nav.footprint_outline(cells)
	var reason := building_block_reason(bid)
	if reason != "": result.reason = reason; return result
	if bid==20 and not _dep_ai_economy._dock_can_launch(point): result.reason="船坞需建在可通航水面旁"; return result
	if not _nav.can_place(cells): return result
	for c in cells:
		if not _dep_spatial_index._cell_unit(c, -1, 0).is_empty(): result.reason = "这里有部队，无法建造"; return result
	var workers: Array = _dep_command_groups._selected_construction_workers(actors)
	if workers.is_empty(): result.reason = "需要带工人的武将队伍"; return result
	if not _economy.can_pay(battle.player_owner, _dep_ai_economy.ai_unit_cost(bid)): result.reason = "资源不足"; return result
	var probe := {"unit":bid,"is_building":true,"occupied_cells":cells,"ax":point.x,"ay":point.y,"w":meta.w,"h":meta.h}
	if not workers.any(func(worker): return not _site_entry_path(worker, probe, cells).is_empty()):
		result.reason = "工人无法进入该工地"; return result
	result.valid = true; result.reason = "点击确认建造"
	return result

func _assign_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	if not _valid_build_worker(worker, site): return false
	if int(worker.get("site_inside_uid", -1)) == int(site.uid): return true
	var path := _site_entry_path(worker, site)
	if path.is_empty(): return false
	_dep_command_groups._cancel_unit_command(worker)
	worker.build_target = site
	worker.state = "build"
	UnitPath.set_points(worker, path)
	return true

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	if not battle.units.any(func(candidate): return is_same(candidate,worker)) or not battle.units.any(func(candidate): return is_same(candidate,site)): return false
	if not bool(worker.get("alive", false)) or float(worker.get("die_t", -1)) >= 0 or bool(worker.get("attached", false)) or not preload("res://simulation/definitions/unit_rules.gd").can_build(worker) or bool(worker.get("is_building", false)): return false
	if worker not in _dep_command_groups._construction_workers(_dep_command_groups._commander_for(worker)): return false
	return bool(site.get("alive", false)) and float(site.get("die_t", -1)) < 0 and bool(site.get("is_building", false)) and bool(site.get("site", false)) and int(worker.get("owner", -1)) == int(site.get("owner", -2))

func _order_build(site: Dictionary, actors = null) -> int:
	if int(site.get("owner", -1)) != battle.player_owner: return 0
	var count := 0
	var workers: Array = _dep_command_groups._selected_construction_workers(actors)
	for worker in workers:
		if _assign_build_worker(worker, site): count += 1
	if count > 0: _construction.order_commander(site, workers)
	_effects.feedback("武将已派出 %d 名工人继续建造「%s」" % [count, str(site.get("name", "?"))] if count > 0 else "需选择带工人队伍的武将，并确保工地可达")
	return count

func _build_site_at(pos: Vector2, opt: Dictionary, actors = null) -> bool:
	var placement := build_placement_at(pos, opt, actors)
	if not bool(placement.valid): _effects.feedback(str(placement.reason)); return false
	var bid := int(opt.get("unit", -1))
	var blocked := building_block_reason(bid)
	if blocked != "":
		_effects.feedback(blocked)
		return false
	if not battle.build_types.any(func(entry): return int(entry.unit) == bid): return false
	var workers: Array = _dep_command_groups._selected_construction_workers(actors)
	var cost: Dictionary = _dep_ai_economy.ai_unit_cost(bid) # 执行入口使用定义造价，不信任UI传入价格。
	if _dep_production._army_count(battle.player_owner) >= Balance.army_cap() or workers.is_empty() or not _economy.pay(battle.player_owner, cost):
		_effects.feedback("无法建造：需带工人的武将队伍、足够资源且未达%d单位上限" % Balance.army_cap())
		return false
	var site := _place_building(battle.player_owner, bid, pos, true, workers, true)
	if site.is_empty():
		_economy.refund(battle.player_owner, cost, 100)
		_effects.feedback("这里放不下「%s」" % str(opt.get("name", "?")))
		return false
	site["build_cost"] = cost
	var n := 0
	for w in workers:
		if _assign_build_worker(w, site): n += 1
	if n > 0:
		_construction.order_commander(site, workers)
		if actors == null or battle.selected == actors: battle.selected = [site]
	_effects.feedback("开工：「%s」工地已放下，%d 名工人前往建造" % [str(opt.get("name", "?")), n])
	return true

func _complete_site(site: Dictionary) -> void:
	if not bool(site.get("site",false)) or not bool(site.get("alive",true)):return
	site["site"] = false
	site["hp"] = float(site.get("maxhp", site.get("hp", 0.0)))
	site["build_frame"] = 0
	var awarded := {}
	for w in battle.units:
		if w.get("build_target") == site:
			var commander: Dictionary = _dep_command_groups._commander_for(w)
			if not commander.is_empty() and not awarded.has(commander.uid):
				_dep_officer_teams._grant_officer_exp(w, float(preload("res://simulation/officers/officer_progression.gd").reward(int(site.unit)).killXp))
				awarded[commander.uid] = true
			w["build_target"] = null
			if str(w.get("state", "")) == "build":
				_dep_command_groups._cancel_unit_command(w)
	_construction.release_site(site)

func _start_build(opt: Dictionary) -> void:
	if battle.game_end != 0:
		return
	if _dep_command_groups._selected_construction_workers().is_empty():
		_effects.feedback("建造由麾下带工人的武将发起；独立工人请先组建队伍")
		return
	_dep_command_groups._cmd_begin("build", opt)

func _cancel_site(site: Dictionary) -> bool:
	if not site.get("site", false) or not site.alive or site.die_t >= 0 or int(site.owner) != battle.player_owner: return false
	_economy.refund(int(site.owner), site.get("build_cost", _dep_ai_economy.ai_unit_cost(int(site.unit))))
	site.site = false
	_dep_combat._kill(site, {})
	return true

func _process_sites(_delta: float) -> void:
	for u in battle.units:
		if not bool(u.get("alive", false)) or u.die_t >= 0 or not bool(u.is_building):
			continue
		var frames: int = maxi(1, int(u.get("count", 1)))
		if u.has("stock"):
			var s0: float = maxf(1.0, float(u.get("stock_max", float(u.get("stock", 1.0)))))
			var left: float = clampf(float(u.get("stock", 0.0)) / s0, 0.0, 1.0)
			u["build_frame"] = clampi(int(round((1.0 - left) * float(frames - 1))), 0, frames - 1)
			continue
		if not bool(u.get("site", false)):
			continue
		if float(u.get("hp", 0.0)) >= float(u.get("maxhp", 1.0)):
			_complete_site(u)
			continue
		u["build_frame"] = preload("res://simulation/definitions/building_rules.gd").construction_frame(float(u.hp),float(u.maxhp),battle.map_data.units.get(str(int(u.unit)),{}),frames)

func _place_building(owner: int, building_type: int, near_px: Vector2, as_site := false, access_workers: Array = [], exact_anchor := false) -> Dictionary:
	var bx := near_px.x
	var by := near_px.y
	var meta: Dictionary = battle.map_data.units.get(str(int(building_type)), {})
	if meta.is_empty():
		return {}
	var w := float(meta.get("w", 88))
	var h := float(meta.get("h", 88))
	# 以目标点为心、按 A* 可行走格向外找第一个能放下的位置
	var c0: Vector2i = _dep_movement._cell_of_px(bx, by) if exact_anchor else _dep_movement._near_walkable(_dep_movement._cell_of_px(bx, by))
	for r in (range(0, 1) if exact_anchor else range(2, 14)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := Vector2i(clampi(c0.x + dx, 0, int(battle.map_data.rows) - 1),
					clampi(c0.y + dy, 0, int(battle.map_data.cols) - 1))
				if _nav.is_solid(cell):
					continue
				var p: Vector2 = _dep_movement._anchor_of(cell.x, cell.y)
				if building_type==20 and not _dep_ai_economy._dock_can_launch(p): continue
				# R02：与 nav.rebuild_buildings 共用同一占地入口（CONF-20 方形）。
				var cells := _nav.building_footprint(int(building_type), p, w)
				if not _nav.can_place(cells):
					continue
				# R04：建筑选址必须检查移动单位的**整块**占格，不能只看锚点。
				var occupied := false
				for footprint_cell in cells:
					if not _dep_spatial_index._cell_unit(footprint_cell,-1,0).is_empty(): occupied=true;break
				if occupied:
					continue
				if not access_workers.is_empty():
					# 先用真实占地校验施工入口；避免第一块空地把工人隔在墙后。
					var probe := {"unit":building_type,"is_building":true,"occupied_cells":cells,"ax":p.x,"ay":p.y,"w":w,"h":h}
					var accessible := access_workers.any(func(worker): return not _site_entry_path(worker, probe, cells).is_empty())
					if not accessible: continue
				var ob := {
					"unit": int(building_type), "owner": owner, "A": cell.x, "B": cell.y,
					"px": p.x - w * 0.5, "py": p.y - h, "w": w, "h": h,
					"tail": [], "sheet": _dep_entity_factory._sheet_ref_for(int(building_type), owner),
				}
				if str(ob.sheet) == "":
					return {}
				var nu: Dictionary = _dep_entity_factory._make_unit(ob, false)
				battle.units.append(nu)
				battle._index_units_size = battle.units.size()
				_dep_spatial_index._target_sync(nu)            # R13：新建筑立即可被索敌
				if int(building_type) in [16, 17]:
					_nav.register_gate(nu)
				else:
					nu["occupied_cells"] = cells
					_nav.occupy(cells, 1)
				if as_site:
					nu["site"] = true
					nu["hp"] = 0.0
					nu["build_frame"] = maxi(0, int(nu.get("count", 1)) - 1)  # 工地＝最残破的一帧
				return nu
	return {}

func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	# 用户确认由武将发起施工；AI如何补工、挑选队伍仍待明确，不凭空创建工人。
	if int(commander.get("owner", -1)) != owner: return false
	var available: Array = _dep_command_groups._construction_workers(commander)
	if available.is_empty(): return false
	var base: Dictionary = _dep_ai_economy.ai_production_building(owner)
	var near := Vector2(float(battle.map_data.terrainW) * 0.5, float(battle.map_data.terrainH) * 0.5)
	if not base.is_empty():
		near = Vector2(base.ax, base.ay)
	# AI与玩家共用施工状态机；没有工人不会创建自动增长的空工地。
	if not _dep_ai_economy.ai_can_build(owner, building_type) or _dep_production._army_count(owner) >= Balance.army_cap(): return false
	var cost: Dictionary = _dep_ai_economy.ai_unit_cost(building_type)
	if not _economy.pay(owner, cost): return false
	var site := _place_building(owner, building_type, near, true, available)
	if site.is_empty():
		_economy.refund(owner, cost, 100)
		return false
	site.build_cost = cost
	var assigned := 0
	for worker in available:
		if _assign_build_worker(worker, site): assigned += 1
	if assigned == 0:
		# 新开工失败；尚无有效施工命令，回滚本次落地与扣费。
		_dep_battle_simulation._free_unit_at(battle.units.find_custom(func(current): return int(current.uid)==int(site.uid) and is_same(current,site)))
		_economy.refund(owner, cost, 100)
		return false
	_construction.order_commander(site, available)
	return true

func bind_dependencies(world: Object) -> void:
	_dep_ai_economy = world.ai_economy
	_dep_battle_simulation = world.battle_simulation
	_dep_combat = world.combat
	_dep_command_groups = world.command_groups
	_dep_entity_factory = world.entity_factory
	_dep_harvest_orders = world.harvest_orders
	_dep_interaction_paths = world.interaction_paths
	_dep_movement = world.movement
	_dep_officer_teams = world.officer_teams
	_dep_production = world.production
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_construction = world.construction
	_economy = world.economy
	_effects = world.effects
	_nav = world.nav


func step_repair(u: Dictionary, delta: float) -> void:
	var rt = u.get("repair_target",null)
	if not (rt is Dictionary) or not rt.get("alive",false) or float(rt.get("die_t",-1)) >= 0 or rt.get("attached",false) or int(rt.owner) != int(u.owner) or not _dep_spatial_index._contains_unit(rt):
		_dep_command_groups._cancel_unit_command(u)
	elif float(rt.hp) >= float(rt.maxhp):
		_dep_command_groups._cancel_unit_command(u)
	elif not _economy.can_pay(int(u.owner),Balance.work().repairCost):
		_dep_command_groups._cancel_unit_command(u); _effects.feedback("修理：四种资源都须多于15")
	elif _dep_interaction_paths._dist_to_obj(u,rt) > Config.GATHER_REACH:
		preload("res://simulation/movement/action_clock.gd").reset(u)
		if u.path.is_empty(): UnitPath.set_points(u, _dep_interaction_paths._interaction_path(u,rt,Config.GATHER_REACH)); u.pi = 0
		if u.path.is_empty(): _dep_command_groups._cancel_unit_command(u); _effects.feedback("工人无法到达该修理目标")
		else: _dep_movement._follow(u,delta)
	else:
		UnitPath.set_points(u, [])
		var offset := Vector2(rt.ax-u.ax,rt.ay-u.ay)
		u.dir = int(round(offset.angle()/(PI/4.0))) & 7
		if preload("res://simulation/movement/action_clock.gd").step(u,"repair",int(rt.uid)):
			if not _do_repair(u,rt) or float(rt.hp) >= float(rt.maxhp): _dep_command_groups._cancel_unit_command(u)

func step_build(u: Dictionary, delta: float) -> void:
	# 建造（模式 8，FUN_0045c320）：走到工地旁，**每 4 tick 给工地 +2 HP**（多工人叠加）。
	var bt = u.get("build_target", null)
	if not (bt is Dictionary) or not _valid_build_worker(u, bt):
		u.state = "idle"; u.build_target = null; u.build_t = 0
	elif _dep_interaction_paths._edge_cell_distance(u, bt) != Config.EDGE_DISTANCE:
		if u.path.is_empty():
			UnitPath.set_points(u, _site_entry_path(u, bt)); u.pi = 0
		if u.path.is_empty():
			u.state = "idle"; u.build_target = null; u.build_t = 0; _effects.feedback("工人无法到达工地")
		else: _dep_movement._follow(u, delta)
	else:
		_construction.enter(u, bt)
