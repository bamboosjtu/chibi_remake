extends RefCounted
## unit actions: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/unit_actions_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _step_unit(u: Dictionary, delta: float) -> void:
	if not bool(u.is_building): preload("res://simulation/systems/locomotion.gd").ensure(u)
	battle.stratagems.begin_update(u)
	_step_unit_inner(u, delta)
	ports._separate_unit(u)
	battle.stratagems.step_effects(u)
	preload("res://simulation/systems/locomotion.gd").step(u)
	# FUN_0045B4E0 expires flags at the END of the 800th unit update.
	preload("res://simulation/systems/tick_timers.gd").step_statuses(u)

func _step_legacy_burn(u: Dictionary, delta: float) -> bool:
	# Legacy saves may still contain the former unit-following burn; new casts use fire_fields.
	if float(u.get("burn_t", 0.0)) > 0.0 and bool(u.get("alive", false)):
		u["burn_t"] = maxf(0.0, float(u["burn_t"]) - delta)
		if not (battle.cheat_invulnerable and int(u.owner) == battle.player_owner):
			u["hp"] = float(u["hp"]) - float(u.get("burn_dps", 0.0)) * delta
		if float(u["hp"]) <= 0.0:
			ports._kill(u, {})
			return true
	return false

func _step_unit_inner(u: Dictionary, delta: float) -> void:
	u.moved = false
	if bool(u.get("attached", false)):
		return
	if _step_legacy_burn(u, delta): return
	# Confusion/rolling idle tasks wait behind the running order, without clearing it.
	if battle.stratagems.active(u):
		u.anim += delta
		return
	if battle.construction.step(u): return
	# 下船按每 4 拍一名推进；船接到新命令也不打断在舱载员的卸载。
	if int(u.get("unit", -1)) == Config.TRANSPORT_UNIT and (bool(u.get("unload_active", false)) or str(u.get("state", "")) == "unload"):
		u.unload_t = int(u.get("unload_t", 0)) + 1
		if int(u.unload_t) % 4 == 0:
			ports._retry_unload(u)
		if int(u.get("carry_n", 0)) <= 0:
			u.unload_active = false
			if str(u.get("state", "")) == "unload": u.state = "idle"
	# 旧存档或旧AI可能留下无武装单位的攻击命令；执行层同样拒绝。
	if u.state == "attack" and not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
		ports._cancel_unit_command(u)
	# 遭遇接战不受战略 AI 的出兵科技/金钱条件限制；忙碌与原地待命单位保留命令。
	preload("res://simulation/systems/engagement.gd").step(battle, u, ports._nearest_enemy)
	# 箭楼独立守卫，AI之间不互相射击。
	var tower := bool(u.is_building) and int(u.unit) in [18,19]
	if tower and u.state == "idle" and not bool(u.get("site", false)) and int(u.get("confused_t", 0)) <= 0:
		var enemy := ports._nearest_enemy(u, float(u.atk_range) * battle.tile_w)
		if not enemy.is_empty():
			u.target = enemy; u.state = "attack"
	# 带将部队的将本体在空闲时跟随正在干活/行军的成员，不把将留在原地。
	if u.state == "idle" and not bool(u.get("hold", false)) and not (u.get("officer", {}) as Dictionary).is_empty():
		var leader_idx := int(u.officer.get("index", -1))
		for member in battle.units:
			if member == u or not bool(member.get("alive", false)) or float(member.get("die_t", -1)) >= 0.0: continue
			if int(member.get("group_officer", -1)) != leader_idx: continue
			if str(member.get("state", "")) in ["move", "gather", "deliver", "build", "repair", "attack"]:
				var follow_to := Vector2(float(member.ax), float(member.ay))
				if Vector2(float(u.ax), float(u.ay)).distance_to(follow_to) > 2.0 * battle.tile_w:
					u.state = "move"
					u.path = ports._path_to(u, follow_to, true)
					u.pi = 0
					break
	if u.state == "attack":
		var t = u.target
		if not (t is Dictionary) or not t.alive or t.die_t >= 0 or t.get("attached",false) or not ports._contains_unit(t):
			ports._cancel_unit_command(u)
		else:
			var offset := Vector2(t.ax-u.ax,t.ay-u.ay)
			var reach: float = preload("res://simulation/systems/combat_rules.gd").effective_range(u)*battle.tile_w
			u.dir = int(round(offset.angle()/(PI/4.0))) & 7
			var strike := preload("res://simulation/systems/action_clock.gd").step(u,"attack",int(t.uid),tower)
			var in_reach := offset.length_squared() <= reach*reach
			# 近战按**近距离格**判定：不叠格后，等距邻格/斜邻格的脚点距离可到 66px，
			# 仍应视为贴脸可攻击（否则会被前面的单位卡在 66px 外）。
			# R06：放宽到两格时必须同时确认中间没有墙/不可通行地形/封闭建筑，
			# 否则会“隔墙扣血”。远程越墙仍走独立规则（不在此补偿内）。
			if not in_reach and preload("res://simulation/systems/combat_rules.gd").effective_range(u) <= 1:
				var uc := ports._unit_cell(u)
				var tc := ports._unit_cell(t)
				in_reach = maxi(absi(uc.x - tc.x), absi(uc.y - tc.y)) <= 2 and ports._melee_line_clear(u, t)
			if in_reach:
				u.path = []; u.pi = 0
				if strike:
					ports._fire_attack(u,t)
			elif tower:
				ports._cancel_unit_command(u)
			else:
				if strike: preload("res://simulation/systems/action_clock.gd").reset(u) # 击发时射程失效，重发同一攻击重新等待。
				u.repath -= delta
				if u.path.is_empty() or u.repath <= 0:
					u.repath = 0.8
					# 近战不能把“敌方占格”当终点（不叠格会停在两格外），
					# 改寻到目标占格旁的落脚格；远程仍寻到目标本身。
					if preload("res://simulation/systems/combat_rules.gd").effective_range(u) <= 1:
						u.path = ports._edge_interaction_path(u, t)
					else:
						u.path = ports._path_to(u,Vector2(t.ax,t.ay),false)
					u.pi = 0
				ports._follow(u,delta)

	elif u.state == "move":
		# REQ-003：行军被新占地截断 → 按**新世界**重寻路（A* 已反映新占地）。
		# 绕得开就继续走向原目的地；绕不开（目的地不可达）才弃单转 idle。
		# 连续被堵却一步都没走出去（blocked_n>2，见 _follow）同样弃单 —— 不会原地无限重试。
		if u.path.is_empty() and u.has("repath_to"):
			var dest: Vector2 = u["repath_to"]
			u.erase("repath_to")
			u.path = ports._path_to(u, dest, true)
			u.pi = 0
			if u.path.is_empty():
				u.state = "idle"
		if ports._follow(u, delta):
			u.state = "idle"
	elif u.state == "join":
		var leader: Dictionary = {}
		for candidate in battle.units:
			if int(candidate.uid) == int(u.get("join_target_uid", -1)): leader = candidate; break
		if leader.is_empty() or not bool(leader.alive) or leader.die_t >= 0 or leader.get("officer", {}).is_empty() or int(leader.owner) != int(u.owner):
			ports._cancel_unit_command(u)
		elif ports._edge_cell_distance(u, leader) <= Config.EDGE_DISTANCE:
			var idx := int(leader.officer.index)
			var members: Array = battle.units.filter(func(member): return bool(member.alive) and member.die_t < 0 and int(member.owner) == int(u.owner) and int(member.get("group_officer", -1)) == idx)
			ports._cancel_unit_command(u)
			if members.size() < Config.TEAM_MAX_MEMBERS:
				u.group_officer = idx
				ports._auto_assign_new_team(idx)
				ports._feedback("已加入%s的队伍" % str(leader.officer.name).replace(" ", ""))
			else: ports._feedback("该队伍已满15名成员")
		else:
			if u.path.is_empty(): u.path = ports._edge_interaction_path(u, leader); u.pi = 0
			if u.path.is_empty(): ports._cancel_unit_command(u); ports._feedback("无法靠近该队伍")
			else: ports._follow(u, delta)
	elif u.state == "board":
		# 装载（模式 0xC）：走到运输船旁 → 附着上船（船计数 +1、HP 累加）。
		var bship = u.get("board_target", null)
		if not (bship is Dictionary) or not battle.transports.valid_ship(bship) or str(bship.state)=="unload" \
				or int(bship.get("unit", -1)) != Config.TRANSPORT_UNIT \
				or int(bship.get("owner", -1)) != int(u.get("owner", -1)):
			u.state = "idle"; u.board_target = null
		elif int(bship.get("carry_n", 0)) >= Config.TRANSPORT_CAPACITY:
			u.state = "idle"; u.board_target = null
			ports._feedback("运输船已满（%d）" % Config.TRANSPORT_CAPACITY)
		elif not battle.transports.adjacent(u,bship):
			if u.path.is_empty():
				u.path = battle.transports.boarding_path(u,bship); u.pi = 0
			if u.path.is_empty():
				u.state = "idle"; u.board_target = null; ports._feedback("无法靠近运输船")
			else: ports._follow(u, delta)
		else:
			u.path = []
			ports._attach_to_ship(u, bship)
	elif u.state == "unload":
		pass # 卸载计时在上面的 unload_active 分支统一推进
	elif u.state == "gather":
		var obj = u.get("gather_obj", null)
		if not (obj is Dictionary) or obj.is_empty():
			u.state = "idle"; u.path = []
		elif not bool(obj.get("alive", false)) or float(obj.get("die_t", -1)) >= 0:
			battle.harvesting.next_target(u, obj)
		elif ports._edge_cell_distance(u, obj) != Config.EDGE_DISTANCE:
			if u.path.is_empty():
				var choice := ports._edge_interaction_choice(u, obj)
				if not choice.is_empty():
					u.gather_obj = choice.object
					u.path = choice.path
				u.pi = 0
			if u.path.is_empty():
				u.state = "idle"; ports._feedback("工人无法到达该资源点边缘")
			else: ports._follow(u, delta)
		else:
			u.path = []
			battle.harvesting.extract(u, obj)
	elif u.state == "deliver":
		var deposits: Array = ports._deposits_for(u, str(u.get("carry_kind", "")))
		var here := Vector2(u.ax, u.ay)
		var arrived: Dictionary = {}
		for building in deposits:
			if ports._deposit_ready(u, building):
				arrived = building; break
		if not arrived.is_empty():
			u.delivery_ticks = int(u.get("delivery_ticks", 0)) + 1
			if int(u.delivery_ticks) % 4 != 0: return
			if ports._deposit_carry(u):
				u.path = []; u.pi = 0
				# 卸货后继续玩家指定的资源，不暗中改采其他种类。
				if u.gather_obj is Dictionary: battle.harvesting.resume_after_deposit(u, u.gather_obj)
				else: u.state = "idle"
			else:
				u.path = []; u.pi = 0
				u.state = "idle"
		else:
			if u.path.is_empty():
				for building in deposits:
					u.path = ports._edge_interaction_path(u, building, {}, Config.DEPOSIT_EDGE_PX); u.pi = 0
					if not u.path.is_empty(): break
			if u.path.is_empty():
				u.state = "idle"; ports._feedback("没有可到达的卸货建筑，工人保留携带资源")
			else: ports._follow(u, delta)
	elif u.state == "rest":
		# 休息（模式 4，FUN_004602e0）：每 REST_TICKS 个逻辑 tick HP +1，满编即结束。
		if float(u.hp) >= float(u.maxhp) - 0.001:
			u.state = "idle"; u.rest_t = 0
		else:
			u.rest_t = int(u.get("rest_t", 0)) + 1
			if int(u.rest_t) >= Config.REST_TICKS:
				u.rest_t = 0
				u.hp = minf(float(u.maxhp), float(u.hp) + 1.0)
			if float(u.hp) >= float(u.maxhp):
				u.state = "idle"; u.rest_t = 0
	elif u.state == "repair":
		var rt = u.get("repair_target",null)
		if not (rt is Dictionary) or not rt.get("alive",false) or float(rt.get("die_t",-1)) >= 0 or rt.get("attached",false) or int(rt.owner) != int(u.owner) or not ports._contains_unit(rt):
			ports._cancel_unit_command(u)
		elif float(rt.hp) >= float(rt.maxhp):
			ports._cancel_unit_command(u)
		elif not battle.economy.can_pay(int(u.owner),{"gold":Config.REPAIR_COST,"wood":Config.REPAIR_COST,"food":Config.REPAIR_COST,"stone":Config.REPAIR_COST}):
			ports._cancel_unit_command(u); ports._feedback("修理：四种资源都须多于15")
		elif ports._dist_to_obj(u,rt) > Config.GATHER_REACH:
			preload("res://simulation/systems/action_clock.gd").reset(u)
			if u.path.is_empty(): u.path = ports._interaction_path(u,rt,Config.GATHER_REACH); u.pi = 0
			if u.path.is_empty(): ports._cancel_unit_command(u); ports._feedback("工人无法到达该修理目标")
			else: ports._follow(u,delta)
		else:
			u.path = []
			var offset := Vector2(rt.ax-u.ax,rt.ay-u.ay)
			u.dir = int(round(offset.angle()/(PI/4.0))) & 7
			if preload("res://simulation/systems/action_clock.gd").step(u,"repair",int(rt.uid)):
				if not ports._do_repair(u,rt) or float(rt.hp) >= float(rt.maxhp): ports._cancel_unit_command(u)

	elif u.state == "build":
		# 建造（模式 8，FUN_0045c320）：走到工地旁，**每 4 tick 给工地 +2 HP**（多工人叠加）。
		var bt = u.get("build_target", null)
		if not (bt is Dictionary) or not ports._valid_build_worker(u, bt):
			u.state = "idle"; u.build_target = null; u.build_t = 0
		elif ports._edge_cell_distance(u, bt) != Config.EDGE_DISTANCE:
			if u.path.is_empty():
				u.path = ports._site_entry_path(u, bt); u.pi = 0
			if u.path.is_empty():
				u.state = "idle"; u.build_target = null; u.build_t = 0; ports._feedback("工人无法到达工地")
			else: ports._follow(u, delta)
		else:
			battle.construction.enter(u, bt)
	# 闲置部队的局部索敌由 engagement 调度，行动仍走统一攻击/寻路分支。
	u.anim += delta
