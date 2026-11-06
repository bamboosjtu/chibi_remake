extends RefCounted
const C = preload("res://simulation/systems/ai_config.gd")
## AI production, construction and tactical decisions, separate from scheduling.
const AIState = preload("res://simulation/systems/ai_state.gd")
var _ai_state: AIState
const THINK_PERIOD = C.THINK_PERIOD
const BUILD_PLAN_PERIOD = C.BUILD_PLAN_PERIOD
const BUILD_STATE_PERIOD = C.BUILD_STATE_PERIOD
const INTERCEPT_PERIOD = C.INTERCEPT_PERIOD
const ASSAULT_PERIOD = C.ASSAULT_PERIOD
const ASSAULT_PERIOD_URGENT = C.ASSAULT_PERIOD_URGENT
const AI_MONEY = C.AI_MONEY
const GIFT_WOOD = C.GIFT_WOOD
const GIFT_FOOD = C.GIFT_FOOD
const GIFT_STONE = C.GIFT_STONE
const HUMAN_GOLD_FOR_ASSAULT = C.HUMAN_GOLD_FOR_ASSAULT

## 当前章节范围与玩家共用用户确认的100/200人生产准入；后续兵种保留在GAP。
const ARMY_BY_TIER = C.ARMY_BY_TIER

## 该方当前的兵种表（按自身等级 0..2 取；超出范围钳制）
const HUMAN_WEAK_UNITS = C.HUMAN_WEAK_UNITS
const INTERCEPT_RADIUS = C.INTERCEPT_RADIUS
const Access = preload("res://simulation/ports/ai_access.gd")
const PLAN_TO_BUILDING = C.PLAN_TO_BUILDING
## **归属奇偶层** —— 订正：此前记录里说"REA 反编译没有奇偶证据"是**错的**。
## 证据就在 `FUN_0046e4b0` 里（`_work/fun_46e4b0.c` 第 27/31/40/41/53/54 行）：
##     if ((param_1 == 1) || (param_1 == 3)) { … = 0xf; return; }   // 奇数归属
##     if ((param_1 != 2) && (param_1 != 4)) { return; } … = 0x10;  // 偶数归属
## `param_1` 就是归属 id。它写成**显式比较**而不是 `% 2`/`& 1`，
## 所以之前按"奇偶形状"去 grep 才会一无所获。
##
## 语义：**同一建筑槽，奇数归属(1,3) 与偶数归属(2,4) 选不同的计划项**，
## 落到的正是 DATA.EXP 里那对"同建筑的两个阵营版本"。
## 下表的键 = 建筑种类（取该对的偶数 id），值 = [奇数归属用的项, 偶数归属用的项]。
const PLAN_PAIR = C.PLAN_PAIR
## 该归属要盖这一"种类"时，原版会写哪个计划项（奇偶决定）
## static：main.gd 的**玩家侧建造**菜单要用同一份「计划项 → 建筑 id」证据，
## 不能另造一套（那会让玩家和 AI 造出不同阵营版本的建筑）。
const BUILD_PRIORITY_KINDS = C.BUILD_PRIORITY_KINDS

## 原版 FUN_0046e4b0：挑下一个要盖的建筑，写计划槽 DAT_005d2000/0x5d2004

func _init(data: AIState) -> void:
	_ai_state = data

func army_for(owner: int) -> Array:
	var lvl: int = clampi(int(_ai_state.host.ai_level(owner)), 0, ARMY_BY_TIER.size() - 1)
	return ARMY_BY_TIER[lvl]

func _think_once(owner: int) -> void:
	# 1) AI 每轮把金钱补满（原版 DAT_004b8d08[owner] = 20000）
	_ai_state.host.ai_set_gold(owner, AI_MONEY)

	# 2) 建造/训练计划：每 22 轮刷新一次，其余轮次推进状态机
	_ai_state._plan[owner] = int(_ai_state._plan.get(owner, 0)) + 1
	if int(_ai_state._plan[owner]) >= BUILD_PLAN_PERIOD:
		_ai_state._plan[owner] = 0
		_refresh_plan(owner)
		_research_plan(owner)
	_slot_train(owner)
	_ai_state.naval.step(owner, naval_slots(_ai_state.host.ai_behavior(owner), _ai_state.host.ai_tech_gate(owner)))
	_train(owner)

	# 3) 撤退按**群**处理：只有正在撤退的群跳过进攻/集结，其他群照常决策。
	var retreating := _retreat_step(owner)
	var skip: Array = retreating.keys()
	# 4) 进攻 / 拦截 / 归队
	_ai_state._assault[owner] = int(_ai_state._assault.get(owner, 0)) + 1
	_ai_state._intercept[owner] = int(_ai_state._intercept.get(owner, 0)) + 1
	if int(_ai_state._intercept[owner]) >= INTERCEPT_PERIOD:
		_ai_state._intercept[owner] = 0
		_intercept_near(owner, skip)
	_assault_maybe(owner, skip)
	_rally(owner, skip)

## 训练：科技闸通过才造；买不起就送资源（原版在 FUN_00471c60 里直接加钱加粮）

func _train(owner: int) -> void:
	var gate: int = int(_ai_state.host.ai_tech_gate(owner))
	var lvl: int = int(_ai_state.host.ai_level(owner))
	if _ai_state.host.ai_behavior(owner) != 0 or (gate > lvl and gate > 0):
		return                              # 科技不够 —— 原版同样不造
	# 四系各自派发，建筑工作锁统一由宿主执行；后续生产开放仍受现有范围限制。
	var order: Array = army_for(owner).duplicate(); order.append(34)
	for unit_id in order:
		if _ai_state.slots.line_busy(owner,int(unit_id)): continue
		var building: Dictionary = _ai_state.host.ai_production_building(owner,int(unit_id))
		if building.is_empty(): continue
		var cost: Dictionary = _ai_state.host.ai_unit_cost(int(unit_id))
		if not _ai_state.host.ai_can_afford(owner,cost):
			_ai_state.host.ai_gift(owner,GIFT_WOOD,GIFT_FOOD,GIFT_STONE)
			continue
		_ai_state.host.ai_enqueue_train(owner,building,int(unit_id),cost)

func _slot_train(owner: int) -> void:
	_ai_state.slots.refresh(owner)
	var allowed := available_slots(_ai_state.host.ai_behavior(owner),_ai_state.host.ai_tech_gate(owner),_ai_state.host.ai_level(owner),_ai_state.host.ai_level(_ai_state.host.player_owner),_ai_state.host.ai_gold(_ai_state.host.player_owner),_ai_state.host.scenario_mission)
	for slot in allowed:
		_ai_state.slots.dispatch(owner,int(slot),army_for(owner))

## 已确认的槽位准入表，与四系训练器保持独立。

func _research_plan(owner: int) -> bool:
	var gate: int = _ai_state.host.ai_tech_gate(owner)
	if gate < 2 or (gate >= 3 and _ai_state.host.ai_behavior(owner) > 1): return false
	var bow := [3] if gate == 2 else ([3,4] if gate == 3 else [3,4,5])
	var equipment := [6,9] if gate == 2 else ([6,9,7,10] if gate == 3 else [6,9,7,10,8,11])
	var families := [bow,equipment]
	if gate >= 3:
		# CONF-17 判定顺序：先船坞 20→21→22（附加闸不可达），再投石 18→19。
		families.append([20,21,22])
		families.append([18,19])
	# 用户确认：船坞研究需四槽舰船在途全非零，但派船全局互锁使其不可达；保留原版不自动派研。
	var cursor := int(_ai_state._research_cursor.get(owner,0)) % families.size()
	for offset in range(families.size()):
		var family := (cursor+offset) % families.size()
		for idx in families[family]:
			if int(idx) in [20,21,22] and not _ai_state.host._naval_research_gate(owner): break
			var line: String = _ai_state.host._tech_line_of(int(idx))
			if _ai_state.host._tech_line_pos(int(idx)) < _ai_state.host._tech_line_progress(line,owner): continue
			var building: Dictionary = _ai_state.host.ai_research_building(owner,int(idx))
			if not building.is_empty() and _ai_state.host._queue_research(owner,building,int(idx),true):
				_ai_state._research_cursor[owner] = (family+1) % families.size()
				return true
			break # 本系前一档未完成，不能跳过它派后档。
	return false

## 进攻闸门（FUN_00471600 的条件逐条照搬；L1 另走槽位顺序目标/单群命令）

func _assault_maybe(owner: int, skip_groups: Array = []) -> void:
	var human_units: int = int(_ai_state.host.ai_force_units(_ai_state.host.player_owner))
	# 玩家 <6 后阈值永久改为6；计数达到阈值后的**下一次**思考才检查（71/7周期）。
	if human_units < HUMAN_WEAK_UNITS:
		_ai_state._assault_period[owner] = ASSAULT_PERIOD_URGENT
	var period := int(_ai_state._assault_period.get(owner, ASSAULT_PERIOD))
	if int(_ai_state._assault[owner]) <= period:
		return
	_ai_state._assault[owner] = 0
	# 原版：自身等级 < 关卡科技闸，且（人类等级 < 闸-1 或 人类金钱 < 15000）→ 按兵不动
	var gate: int = int(_ai_state.host.ai_tech_gate(owner))
	var my_lvl: int = int(_ai_state.host.ai_level(owner))
	var human_lvl: int = int(_ai_state.host.ai_level(_ai_state.host.player_owner))
	var human_gold: float = float(_ai_state.host.ai_gold(_ai_state.host.player_owner))
	if human_units >= HUMAN_WEAK_UNITS and my_lvl < gate and (human_lvl < gate - 1 or human_gold < HUMAN_GOLD_FOR_ASSAULT):
		return
	if _ai_state.host.map_id == "chibil1":
		_ai_state.host.ai_order_assault_l1(owner, skip_groups)
	else:
		_ai_state.host.ai_order_assault(owner, skip_groups)

## 局部拦截（FUN_00471fd0）：把焦点单位周围 ±90 内的部队叫去拦截

func _intercept_near(owner: int, skip_groups: Array = []) -> void:
	# 原版拦截以本方建筑坐标为中心；L1 电脑没有建筑，不拦截。
	if _ai_state.host.ai_production_building(owner).is_empty():
		return
	var focus: Dictionary = _ai_state.host.ai_focus_unit(owner)
	if focus.is_empty() or skip_groups.has(int(_ai_state.host.ai_group_of(focus))):
		return
	_ai_state.host.ai_order_intercept(owner, focus, INTERCEPT_RADIUS, skip_groups)

## 归队 / 集结（FUN_0044b600）：把闲置或离得太远的部队拉回自家集结点

func _rally(owner: int, skip_groups: Array = []) -> void:
	_ai_state.host.ai_order_rally(owner, skip_groups)

## 建造计划项(1..0x14) → 建筑类型（**DATA.EXP 建筑 id**）。
## 直接取自 CB.EXE `FUN_004675b0` 里 0x467861 处的跳转表（REA 反编译原文）：
##   1→0 2→1 3→8 4→9 5→0xe 6→0xf 7→6 8→7 9→0xc 10→0xd 0xb→0x12 0xc→0x13
##   0xd→2 0xe→3 0xf→10 0x10→0xb 0x11→4 0x12→5 0x13→0x14 0x14→0x17
## 注意成对出现（(1,2)/(3,4)/(5,6)…），对应的正是 DATA.EXP 建筑表里
## 「同一建筑的两个阵营版本」——所以原型把成对的 id 归为同一个"种类"。

func _refresh_plan(owner: int) -> void:
	_ai_state.host.ai_queue_hq_upgrade(owner)
	var have: Array = _ai_state.host.ai_building_kinds(owner)
	have.append_array(_ai_state.host.ai_construction_kinds(owner)) # 预留工地不重复下单，但不算解锁前置。
	var priority: Array = [0,10,12,4,14] if _ai_state.host.ai_tech_gate(owner) == 1 and _ai_state.host.ai_behavior(owner) == 0 else BUILD_PRIORITY_KINDS
	for kind in priority:
		if have.has(int(kind)):
			continue                                # 这一类已经有了
		# 奇偶层：同一槽位，奇数归属与偶数归属拿到的建筑 id 不同
		var item := plan_item_for(int(kind), owner)
		if item <= 0:
			continue
		var bt: int = int(PLAN_TO_BUILDING.get(item, -1))
		if bt < 0:
			continue
		if not _ai_state.host.ai_can_build(owner, bt):
			continue                                # 科技闸/造价不够
		_ai_state.plan[owner] = item
		return
	_ai_state.plan[owner] = 0

## 执行建造计划（对应原版 FUN_004675b0 的收尾：选址 → 入队指令 0x19/mode 2）
## CONF-16：每势力施工群目标 5 名工人，少于 5 时每轮补 1 名。
## R11：补员必须先**交付到施工队**——人数够 5 但全员未编组不算恢复施工能力。

func _worker_step(owner: int) -> void:
	var commander := _maintain_construction_team(owner)
	var team_size := 0
	if not commander.is_empty():
		team_size = _ai_state.host._construction_workers(commander).size()
	# 训练闸看**施工群人数**，不是全势力工人数：5 名采集工人不能顶替施工队。
	if team_size >= 5:
		return
	if commander.is_empty() and int(_ai_state.host.ai_worker_count(owner)) >= 5:
		return                        # 没有空闲队长时不再堆工人（等编制释放）
	var building: Dictionary = _ai_state.host.ai_production_building(owner, 30)
	if building.is_empty():
		return
	var cost: Dictionary = _ai_state.host.ai_unit_cost(30)
	if not _ai_state.host.ai_can_afford(owner, cost):
		return
	_ai_state.host.ai_enqueue_train(owner, building, 30, cost)

## R11：把一个空闲武将（本来没有成员）设为施工队长，并把空闲、未编组、
## 没有采集/运输/修理/施工任务的工人补到 5 名。不抢正在工作的工人。

func _maintain_construction_team(owner: int) -> Dictionary:
	var commander: Dictionary = _ai_state.host.ai_construction_commander(owner)
	if commander.is_empty():
		commander = _spare_construction_officer(owner)
	if commander.is_empty():
		return {}
	var index := int(commander.officer.index)
	var members: Array = _ai_state.host._construction_workers(commander)
	if members.is_empty():
		# ai_construction_commander 只接受“已有成员且全空闲”的队；这里允许新队长从 0 开始。
		members = []
		for u in _ai_state.host.units:
			if u == commander or int(u.get("owner", -1)) != owner: continue
			if int(u.get("group_officer", -1)) == index and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0:
				members.append(u)
	var need := 5 - members.size()
	if need <= 0:
		return commander
	var pool: Array = []
	for w in _ai_state.host.units:
		if int(w.get("owner", -1)) != owner or int(w.get("unit", -1)) != 30: continue
		if not bool(w.get("alive", false)) or float(w.get("die_t", -1)) >= 0.0: continue
		if bool(w.get("is_building", false)) or bool(w.get("attached", false)): continue
		if int(w.get("group_officer", -1)) >= 0: continue
		if str(w.get("state", "idle")) != "idle" or bool(w.get("hold", false)): continue
		if float(w.get("carry", 0.0)) > 0.0: continue
		if w.get("gather_obj") is Dictionary or w.get("build_target") is Dictionary or w.get("repair_target") is Dictionary: continue
		pool.append(w)
	pool.sort_custom(func(a, b): return int(a.get("uid", -1)) < int(b.get("uid", -1)))
	for i in range(mini(need, pool.size())):
		pool[i]["group_officer"] = index
	return commander

## 空闲且没有任何成员的武将（含原施工队长阵亡后空出来的队长）。已有成员的队长
## 不会被再次选中，避免一队两个武将。

func _spare_construction_officer(owner: int) -> Dictionary:
	for u in _ai_state.host.units:
		if int(u.get("owner", -1)) != owner or bool(u.get("is_building", false)): continue
		if not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0: continue
		if bool(u.get("attached", false)) or not _ai_state.host._is_hero_unit(u): continue
		if (u.get("officer", {}) as Dictionary).is_empty(): continue
		if str(u.get("state", "idle")) != "idle": continue
		var index := int(u.officer.index)
		var has_members := false
		for m in _ai_state.host.units:
			if m == u or int(m.get("owner", -1)) != owner: continue
			if not bool(m.get("alive", false)) or float(m.get("die_t", -1)) >= 0.0: continue
			if int(m.get("group_officer", -1)) == index:
				has_members = true
				break
		if not has_members:
			return u
	return {}

## 该势力的武将群：群号 -> [群主, 成员...]。群主排第一，供撤退锚点使用。

func _officer_groups(owner: int) -> Dictionary:
	var groups := {}
	for u in _ai_state.host.units:
		if int(u.get("owner", -1)) != owner or bool(u.get("is_building", false)): continue
		if not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0: continue
		if bool(u.get("attached", false)): continue
		var officer: Dictionary = u.get("officer", {})
		if officer.is_empty(): continue
		groups[int(officer.index)] = [u]
	for u in _ai_state.host.units:
		if int(u.get("owner", -1)) != owner or bool(u.get("is_building", false)): continue
		if not bool(u.get("alive", false)) or float(u.get("die_t", -1)) >= 0.0: continue
		if bool(u.get("attached", false)): continue
		if not (u.get("officer", {}) as Dictionary).is_empty(): continue
		var group := int(u.get("group_officer", -1))
		if groups.has(group):
			groups[group].append(u)
	return groups

## CONF-09：**按群**处理撤退——锚点有存活攻击者 → 该群向锚点 (−20,−20) 收拢；
## 锚点命令结束（模式 0）才恢复。历史攻击者记录在触发时消费，旧伤不会反复触发。
## 返回仍在撤退中的群号 -> 1，供进攻/拦截/集结跳过这些群。

func _retreat_step(owner: int) -> Dictionary:
	var groups := _officer_groups(owner)
	var had = _ai_state._retreat.get(owner, {})
	if not had is Dictionary:
		had = {}                      # 旧档迁移：int 只表示“曾在撤退”，无法定位群
	_ai_state._retreat[owner] = had
	var active := {}
	for group in groups:
		var idx := int(group)
		var members: Array = groups[group]
		if members.is_empty(): continue
		var anchor: Dictionary = members[0]
		if had.has(idx):
			# 恢复只看锚点命令是否结束；不依赖原先的受击目标。
			if str(anchor.get("state", "")) == "idle":
				had.erase(idx)
			else:
				active[idx] = 1
			continue
		if _living_attacker(anchor, owner).is_empty():
			continue
		had[idx] = 1
		active[idx] = 1
		var target := Vector2(maxf(2.0, float(anchor.ax) - 20.0), maxf(2.0, float(anchor.ay) - 20.0))
		for m in members:
			_ai_state.host._cancel_unit_command(m)
			m.state = "move"
			m.path = _ai_state.host._path_to(m, target, true)
			m.pi = 0
			# 消费这次受击记录：没有新伤害就不能在恢复后再次触发。
			m["last_attacker_uid"] = -1
	# 群主阵亡/解散后清理失效的撤退项。
	for idx in had.keys():
		if not groups.has(idx):
			had.erase(idx)
	if had.is_empty():
		_ai_state._retreat.erase(owner)
	return active

func _living_attacker(anchor: Dictionary, owner: int) -> Dictionary:
	var aid := int(anchor.get("last_attacker_uid", -1))
	if aid < 0: return {}
	for e in _ai_state.host.units:
		if int(e.get("uid", -1)) != aid: continue
		if not bool(e.get("alive", false)) or float(e.get("die_t", -1)) >= 0.0: continue
		if not _ai_state.host._hostile_owners(owner, int(e.get("owner", -1))): continue
		return e
	return {}

func _build_step(owner: int) -> void:
	var item: int = int(_ai_state.plan.get(owner, 0))
	if item <= 0:
		return
	var bt: int = int(PLAN_TO_BUILDING.get(item, -1))
	if bt < 0:
		_ai_state.plan[owner] = 0
		return
	if not _ai_state.host.ai_can_build(owner, bt):
		_ai_state.plan[owner] = 0
		return
	var commander: Dictionary = _ai_state.host.ai_construction_commander(owner)
	if commander.is_empty(): return # 没有现成空闲工人队伍；自动补工策略待确认。
	if _ai_state.host.ai_place_building(owner, bt, commander):
		_ai_state.plan[owner] = 0


static func available_slots(behavior: int, gate: int, level: int, human_level: int, human_gold: float, mission: int) -> Array:
	match behavior:
		0:
			match gate:
				1: return [0] if human_gold > 9999 else []
				2:
					var out := [0]
					if level > 0: out.append_array([1,2])
					return out
				3:
					var out := [0]
					if level > 0 and human_gold > 19999: out.append(1)
					if level > 1: out.append(2)
					return out
				4:
					var out := [0]
					if level > 1 and human_level > 1: out.append(1)
					if level > 2: out.append(2)
					return out
		1:
			match gate:
				1,2: return [0]
				3: return [0,3]
				4: return [3]
		2:
			if mission == 0: return []
			match gate:
				1: return [0] if human_gold > 9999 else []
				2:
					var out := [0]
					if level > 0: out.append_array([1,2])
					if mission == 30: out.append_array([1,2])
					return out
				3:
					var out := [0]
					if level > 0 and human_gold > 19999: out.append(1)
					if level > 1: out.append(2)
					if mission == 30: out.append_array([1,2])
					return out
				4:
					var out := [0]
					if level > 1 and human_level > 1: out.append(1)
					if level > 2: out.append(2)
					if mission == 30: out.append_array([1,2])
					return out
	return []

## 水军槽准入（CONF-18E）：仅行为档位 1；与陆军槽独立。

static func naval_slots(behavior: int, gate: int) -> Array:
	if behavior != 1: return []
	match gate:
		1,2: return [0]
		3: return [0,3]
		4: return [0,1,3]
	return []

## 每22次思考最多一道普通研究；HQ在建造/经济计划内独立派发。

static func plan_item_for(kind: int, owner: int) -> int:
	var pr: Array = PLAN_PAIR.get(int(kind), [])
	if pr.is_empty():
		return 0
	return int(pr[0]) if (owner % 2) == 1 else int(pr[1])

## 建造优先序：帅帐 → 兵营系 → 经济 → 防御 → 船坞。
## 原版 `FUN_0046e4b0` 是「科技闸 → 自身等级 → 已有建筑槽 → 归属奇偶」四层 switch；
## 原型只实现**科技闸 + 已有建筑**两层（等级与奇偶未建模，见 docs/AI.md §4）。
## 建造优先序，按**建筑种类**（= PLAN_PAIR 的键，即偶数 id）排列。
## 原版 `FUN_0046e4b0` 是「科技闸 → 自身等级 → 已有建筑槽 → **归属奇偶**」四层；
## 等级层由 ARMY_BY_TIER 覆盖（那层是兵种表），这里覆盖槽位与奇偶两层。
