extends RefCounted
## construction orders: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/construction_orders_dependencies.gd")
var battle: State
var ports := Dependencies.new()

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

func _order_repair(target: Dictionary) -> int:
	if bool(target.get("site", false)):
		return _order_build(target)
	if target.is_empty() or not bool(target.get("alive", false)) or float(target.get("die_t", -1)) >= 0 or bool(target.get("attached", false)) or int(target.get("owner", -1)) != battle.player_owner:
		ports._feedback("修理对象必须是我方单位或建筑")
		return 0
	var n := 0
	for w in ports._selected_workers():
		if not w.alive or w.die_t >= 0.0 or not ports._is_worker_unit(w):
			continue
		ports._cancel_unit_command(w)
		w["repair_target"] = target
		w["state"] = "repair"
		w["path"] = ports._interaction_path(w, target, Config.GATHER_REACH)
		w["pi"] = 0
		n += 1
	if n > 0:
		ports._feedback("%d 名工人前往修理「%s」" % [n, str(target.get("name", "?"))])
	else:
		ports._feedback("只有工兵可以修理")
	return n

func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	# 目标可能在工人接令后死亡/上船；执行时重验，不能给淡出中的尸体回血扣款。
	if not bool(w.get("alive", false)) or float(w.get("die_t", -1)) >= 0 or not ports._is_worker_unit(w): return false
	if not bool(t.get("alive", false)) or float(t.get("die_t", -1)) >= 0 or bool(t.get("attached", false)) or bool(t.get("site", false)) or int(t.get("owner", -1)) != int(w.owner): return false
	if float(t.hp) >= float(t.maxhp): return false
	if not battle.economy.pay(int(w.owner), {"gold":Config.REPAIR_COST,"wood":Config.REPAIR_COST,"food":Config.REPAIR_COST,"stone":Config.REPAIR_COST}):
		ports._feedback("修理：四种资源都须多于 15")
		return false
	var before := float(t.get("hp", 0.0))
	var cap := float(t.get("maxhp", before))
	t["hp"] = minf(cap, before + Config.REPAIR_HP)
	ports._feedback("修理「%s」：+%d 兵力（%.0f/%.0f）" % [
		str(t.get("name", "?")), int(float(t["hp"]) - before), float(t["hp"]), cap])

	return true

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	var origin := Vector2(float(unit.ax), float(unit.ay))
	if future_cells.is_empty() and ports._edge_cell_distance(unit, site) == Config.EDGE_DISTANCE:
		return [origin]
	var candidates := ports._edge_neighbors(site, int(unit.uid))
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(battle.nav.anchor_of(a.x, a.y)) < origin.distance_squared_to(battle.nav.anchor_of(b.x, b.y)))
	for cell in candidates:
		var target := battle.nav.anchor_of(cell.x, cell.y)
		var path := battle.nav.find_path_avoiding(origin, target, true, future_cells, ports._nav_layer(unit), int(unit.owner), int(unit.unit))
		if not path.is_empty() and battle.nav.cell_of_px(path.back().x, path.back().y) == cell: return path
	return []

func build_placement_at(pos: Vector2, opt: Dictionary) -> Dictionary:
	var bid := int(opt.get("unit", -1))
	var cell := ports._cell_of_px(pos.x, pos.y)
	var point := battle.nav.anchor_of(cell.x, cell.y)
	var meta: Dictionary = battle.map_data.units.get(str(bid), {})
	var result := {"valid":false, "unit":bid, "anchor":point, "cells":[], "outline":PackedVector2Array(), "reason":"地形不对，无法建造"}
	if meta.is_empty(): return result
	if battle.game_end != 0 or not battle.build_types.any(func(entry): return int(entry.unit) == bid): return result
	if ports._army_count(battle.player_owner) >= 200: result.reason = "已达200单位上限"; return result
	var cells := battle.nav.building_footprint(bid, point, float(meta.w))
	result.cells = cells
	result.outline = battle.nav.footprint_outline(cells)
	var reason := building_block_reason(bid)
	if reason != "": result.reason = reason; return result
	if bid==20 and not ports._dock_can_launch(point): result.reason="船坞需建在可通航水面旁"; return result
	if not battle.nav.can_place(cells): return result
	for c in cells:
		if not ports._cell_unit(c, -1, 0).is_empty(): result.reason = "这里有部队，无法建造"; return result
	var workers := ports._selected_construction_workers()
	if workers.is_empty(): result.reason = "需要带工人的武将队伍"; return result
	if not battle.economy.can_pay(battle.player_owner, ports.ai_unit_cost(bid)): result.reason = "资源不足"; return result
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
	ports._cancel_unit_command(worker)
	worker.build_target = site
	worker.state = "build"
	worker.path = path
	return true

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	if not battle.units.has(worker) or not battle.units.has(site): return false
	if not bool(worker.get("alive", false)) or float(worker.get("die_t", -1)) >= 0 or bool(worker.get("attached", false)) or not preload("res://simulation/systems/unit_rules.gd").can_build(worker) or bool(worker.get("is_building", false)): return false
	if worker not in ports._construction_workers(ports._commander_for(worker)): return false
	return bool(site.get("alive", false)) and float(site.get("die_t", -1)) < 0 and bool(site.get("is_building", false)) and bool(site.get("site", false)) and int(worker.get("owner", -1)) == int(site.get("owner", -2))

func _order_build(site: Dictionary) -> int:
	if int(site.get("owner", -1)) != battle.player_owner: return 0
	var count := 0
	var workers := ports._selected_construction_workers()
	for worker in workers:
		if _assign_build_worker(worker, site): count += 1
	if count > 0: battle.construction.order_commander(site, workers)
	ports._feedback("武将已派出 %d 名工人继续建造「%s」" % [count, str(site.get("name", "?"))] if count > 0 else "需选择带工人队伍的武将，并确保工地可达")
	return count

func _build_site_at(pos: Vector2, opt: Dictionary) -> bool:
	var placement := build_placement_at(pos, opt)
	if not bool(placement.valid): ports._feedback(str(placement.reason)); return false
	var bid := int(opt.get("unit", -1))
	var blocked := building_block_reason(bid)
	if blocked != "":
		ports._feedback(blocked)
		return false
	if not battle.build_types.any(func(entry): return int(entry.unit) == bid): return false
	var workers := ports._selected_construction_workers()
	var cost := ports.ai_unit_cost(bid) # 执行入口使用定义造价，不信任UI传入价格。
	if ports._army_count(battle.player_owner) >= 200 or workers.is_empty() or not battle.economy.pay(battle.player_owner, cost):
		ports._feedback("无法建造：需带工人的武将队伍、足够资源且未达200单位上限")
		return false
	var site := _place_building(battle.player_owner, bid, pos, true, workers, true)
	if site.is_empty():
		battle.economy.refund(battle.player_owner, cost, 100)
		ports._feedback("这里放不下「%s」" % str(opt.get("name", "?")))
		return false
	site["build_cost"] = cost
	var n := 0
	for w in workers:
		if _assign_build_worker(w, site): n += 1
	if n > 0:
		battle.construction.order_commander(site, workers)
		battle.selected = [site]
	ports._feedback("开工：「%s」工地已放下，%d 名工人前往建造" % [str(opt.get("name", "?")), n])
	return true

func _complete_site(site: Dictionary) -> void:
	if not bool(site.get("site",false)) or not bool(site.get("alive",true)):return
	site["site"] = false
	site["hp"] = float(site.get("maxhp", site.get("hp", 0.0)))
	site["build_frame"] = 0
	var awarded := {}
	for w in battle.units:
		if w.get("build_target") == site:
			var commander := ports._commander_for(w)
			if not commander.is_empty() and not awarded.has(commander.uid):
				ports._grant_officer_exp(w, float(preload("res://simulation/systems/officer_progression.gd").reward(int(site.unit)).killXp))
				awarded[commander.uid] = true
			w["build_target"] = null
			if str(w.get("state", "")) == "build":
				ports._cancel_unit_command(w)
	battle.construction.release_site(site)

func _start_build(opt: Dictionary) -> void:
	if battle.game_end != 0:
		return
	if ports._selected_construction_workers().is_empty():
		ports._feedback("建造由麾下带工人的武将发起；独立工人请先组建队伍")
		return
	ports._cmd_begin("build", opt)

func _cancel_site(site: Dictionary) -> bool:
	if not site.get("site", false) or not site.alive or site.die_t >= 0 or int(site.owner) != battle.player_owner: return false
	battle.economy.refund(int(site.owner), site.get("build_cost", ports.ai_unit_cost(int(site.unit))))
	site.site = false
	ports._kill(site, {})
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
		u["build_frame"] = preload("res://simulation/systems/building_rules.gd").construction_frame(float(u.hp),float(u.maxhp),battle.map_data.units.get(str(int(u.unit)),{}),frames)

func _place_building(owner: int, building_type: int, near_px: Vector2, as_site := false, access_workers: Array = [], exact_anchor := false) -> Dictionary:
	var bx := near_px.x
	var by := near_px.y
	var meta: Dictionary = battle.map_data.units.get(str(int(building_type)), {})
	if meta.is_empty():
		return {}
	var w := float(meta.get("w", 88))
	var h := float(meta.get("h", 88))
	# 以目标点为心、按 A* 可行走格向外找第一个能放下的位置
	var c0 := ports._cell_of_px(bx, by) if exact_anchor else ports._near_walkable(ports._cell_of_px(bx, by))
	for r in (range(0, 1) if exact_anchor else range(2, 14)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := Vector2i(clampi(c0.x + dx, 0, int(battle.map_data.rows) - 1),
					clampi(c0.y + dy, 0, int(battle.map_data.cols) - 1))
				if battle.nav.is_solid(cell):
					continue
				var p := ports._anchor_of(cell.x, cell.y)
				if building_type==20 and not ports._dock_can_launch(p): continue
				# R02：与 nav.rebuild_buildings 共用同一占地入口（CONF-20 方形）。
				var cells := battle.nav.building_footprint(int(building_type), p, w)
				if not battle.nav.can_place(cells):
					continue
				# R04：建筑选址必须检查移动单位的**整块**占格，不能只看锚点。
				var cell_set := {}
				for raw in cells:
					cell_set[raw] = true
				var occupied := false
				for existing in battle.units:
					if not bool(existing.get("alive", false)) or float(existing.get("die_t", -1)) >= 0.0:
						continue
					if bool(existing.get("is_building", false)) or int(existing.get("site_inside_uid", -1)) >= 0:
						continue            # 建筑已在 nav 占用中（can_place 已判）
					for footprint_cell in ports._footprint_cells(existing):
						if cell_set.has(footprint_cell):
							occupied = true
							break
					if occupied:
						break
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
					"tail": [], "sheet": ports._sheet_ref_for(int(building_type), owner),
				}
				if str(ob.sheet) == "":
					return {}
				var nu: Dictionary = ports._make_unit(ob, false)
				battle.units.append(nu)
				battle._index_units_size = battle.units.size()
				ports._target_sync(nu)            # R13：新建筑立即可被索敌
				if int(building_type) in [16, 17]:
					battle.nav.register_gate(nu)
				else:
					nu["occupied_cells"] = cells
					battle.nav.occupy(cells, 1)
				if as_site:
					nu["site"] = true
					nu["hp"] = 0.0
					nu["build_frame"] = maxi(0, int(nu.get("count", 1)) - 1)  # 工地＝最残破的一帧
				return nu
	return {}

func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	# 用户确认由武将发起施工；AI如何补工、挑选队伍仍待明确，不凭空创建工人。
	if int(commander.get("owner", -1)) != owner: return false
	var available := ports._construction_workers(commander)
	if available.is_empty(): return false
	var base := ports.ai_production_building(owner)
	var near := Vector2(float(battle.map_data.terrainW) * 0.5, float(battle.map_data.terrainH) * 0.5)
	if not base.is_empty():
		near = Vector2(base.ax, base.ay)
	# AI与玩家共用施工状态机；没有工人不会创建自动增长的空工地。
	if not ports.ai_can_build(owner, building_type) or ports._army_count(owner) >= 200: return false
	var cost := ports.ai_unit_cost(building_type)
	if not battle.economy.pay(owner, cost): return false
	var site := _place_building(owner, building_type, near, true, available)
	if site.is_empty():
		battle.economy.refund(owner, cost, 100)
		return false
	site.build_cost = cost
	var assigned := 0
	for worker in available:
		if _assign_build_worker(worker, site): assigned += 1
	if assigned == 0:
		# 新开工失败；尚无有效施工命令，回滚本次落地与扣费。
		ports._free_unit_at(battle.units.find(site))
		battle.economy.refund(owner, cost, 100)
		return false
	battle.construction.order_commander(site, available)
	return true
