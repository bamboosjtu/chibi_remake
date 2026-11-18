extends RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## unit actions: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const ProfileClock = preload("res://simulation/definitions/profile_clock.gd")
const Config = preload("res://simulation/battle_config.gd")
const REQUIRED_SERVICES := {"battle_simulation": ["_feedback"], "combat": ["_fire_attack", "_melee_line_clear", "_nearest_enemy"], "command_groups": ["_cancel_unit_command"], "construction_orders": ["_do_repair", "_site_entry_path", "_valid_build_worker"], "harvest_orders": ["_deposit_carry", "_deposits_for"], "interaction_paths": ["_deposit_ready", "_dist_to_obj", "_edge_cell_distance", "_edge_interaction_choice", "_edge_interaction_path", "_interaction_path"], "movement": ["_follow", "_path_to"], "officer_teams": ["_auto_assign_new_team"], "spatial_index": ["_contains_unit", "_separate_unit", "_unit_cell"], "transport_orders": ["_attach_to_ship", "_retry_unload"]}
var battle: State
var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)
var profile_enabled := false
var profile: Dictionary={}

func _init(data: State) -> void:
	battle = data

func _step_unit(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["spatial_index"])
	if services.is_empty(): return
	if profile_enabled:
		_step_unit_profiled(u,delta);return
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null and _try_native_attack(u,delta,kernel):return
	preload("res://simulation/systems/stratagem_rules.gd").begin_update(u)
	_step_unit_inner(u, delta)
	services.spatial_index._separate_unit(u)
	battle.stratagems.step_effects(u)
	if kernel!=null:kernel.finish_unit(u)
	else:
		preload("res://simulation/systems/locomotion.gd").step_script(u)
		preload("res://simulation/systems/tick_timers.gd").step_statuses_script(u)

func _step_unit_profiled(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["spatial_index"])
	if services.is_empty(): return
	var at:=ProfileClock.now(profile_enabled)
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null and _try_native_attack(u,delta,kernel):
		_profile_time("nativeAttack",at);profile["units"]=int(profile.get("units",0))+1;return
	preload("res://simulation/systems/stratagem_rules.gd").begin_update(u);at=_profile_time("beginStatus",at)
	_step_unit_inner(u,delta);var end:=ProfileClock.now(profile_enabled)
	var key: String="kind%d" % int(u.unit);profile[key]=int(profile.get(key,0))+end-at
	at=_profile_time("action",at)
	services.spatial_index._separate_unit(u);at=_profile_time("separation",at)
	battle.stratagems.step_effects(u);at=_profile_time("effects",at)
	preload("res://simulation/systems/locomotion.gd").step(u);at=_profile_time("locomotion",at)
	preload("res://simulation/systems/tick_timers.gd").step_statuses(u);_profile_time("timers",at)
	profile["units"]=int(profile.get("units",0))+1

func _profile_time(key: String, at: int) -> int:
	var now:=ProfileClock.now(profile_enabled);profile[key]=int(profile.get(key,0))+now-at;return now


func _step_unit_inner(u: Dictionary, delta: float) -> void:
	var phase := ProfileClock.now(profile_enabled)
	if not _prepare_action(u, delta): return
	if profile_enabled: _profile_time("prepare", phase)
	match str(u.state):
		"attack": _step_attack(u, delta, _is_tower(u))
		"move": _step_move(u, delta)
		"join": _step_join(u, delta)
		"board": _step_board(u, delta)
		"gather": _step_gather(u, delta)
		"deliver":
			# Delivery waits deliberately skip animation, as in the original tick.
			if not _step_deliver(u, delta): return
		"rest": _step_rest(u, delta)
		"repair": _step_repair(u, delta)
		"build": _step_build(u, delta)
	# Idle, unload and passive states share the same final animation step.
	u.anim += delta

func _is_tower(u: Dictionary) -> bool:
	return bool(u.is_building) and int(u.unit) in [18,19]

func _prepare_action(u: Dictionary, delta: float) -> bool:
	var services := ports.acquire(["transport_orders", "command_groups", "combat"])
	if services.is_empty(): return false
	u.moved = false
	if bool(u.get("attached", false)):
		return false
	# Confusion/rolling idle tasks wait behind the running order, without clearing it.
	if preload("res://simulation/systems/stratagem_rules.gd").active(u):
		u.anim += delta
		return false
	if (int(u.get("site_inside_uid",-1))>=0 or int(u.get("site_follow_uid",-1))>=0) and battle.construction.step(u): return false
	# 下船按每 4 拍一名推进；船接到新命令也不打断在舱载员的卸载。
	if int(u.get("unit", -1)) == Roles.transport_id() and (bool(u.get("unload_active", false)) or str(u.get("state", "")) == "unload"):
		u.unload_t = int(u.get("unload_t", 0)) + 1
		if int(u.unload_t) % 4 == 0:
			services.transport_orders._retry_unload(u)
		if int(u.get("carry_n", 0)) <= 0:
			u.unload_active = false
			if str(u.get("state", "")) == "unload": u.state = "idle"
	# 旧存档或旧AI可能留下无武装单位的攻击命令；执行层同样拒绝。
	if u.state == "attack" and not preload("res://simulation/systems/combat_rules.gd").can_attack(u):
		services.command_groups._cancel_unit_command(u)
	# 遭遇接战不受战略 AI 的出兵科技/金钱条件限制；忙碌与原地待命单位保留命令。
	if u.state=="idle":preload("res://simulation/systems/engagement.gd").step(battle, u, services.combat._nearest_enemy)
	# 箭楼独立守卫，AI之间不互相射击。
	var tower := _is_tower(u)
	if tower and u.state == "idle" and not bool(u.get("site", false)) and int(u.get("confused_t", 0)) <= 0:
		var enemy: Dictionary = services.combat._nearest_enemy(u, float(u.atk_range) * battle.tile_w)
		if not enemy.is_empty():
			u.target = enemy; u.state = "attack"
	_follow_working_members(u)
	return true

func _follow_working_members(u: Dictionary) -> void:
	var services := ports.acquire(["movement"])
	if services.is_empty(): return
	# 带将部队的将本体在空闲时跟随正在干活/行军的成员，不把将留在原地。
	if u.state == "idle" and not bool(u.get("hold", false)) and not (u.get("officer", {}) as Dictionary).is_empty():
		var leader_idx := int(u.officer.get("index", -1))
		for member in battle.units:
			if is_same(member, u) or not bool(member.get("alive", false)) or float(member.get("die_t", -1)) >= 0.0: continue
			if int(member.get("group_officer", -1)) != leader_idx: continue
			if str(member.get("state", "")) in ["move", "gather", "deliver", "build", "repair", "attack"]:
				var follow_to := Vector2(float(member.ax), float(member.ay))
				if Vector2(float(u.ax), float(u.ay)).distance_to(follow_to) > 2.0 * battle.tile_w:
					u.state = "move"
					u.path = services.movement._path_to(u, follow_to, true)
					u.pi = 0
					break

func _step_move(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["movement"])
	if services.is_empty(): return
	# REQ-003：行军被新占地截断 → 按**新世界**重寻路（A* 已反映新占地）。
	# 绕得开就继续走向原目的地；绕不开（目的地不可达）才弃单转 idle。
	# 连续被堵却一步都没走出去（blocked_n>2，见 _follow）同样弃单 —— 不会原地无限重试。
	if u.path.is_empty() and u.has("repath_to"):
		var dest: Vector2 = u["repath_to"]
		u.erase("repath_to")
		u.path = services.movement._path_to(u, dest, true)
		u.pi = 0
		if u.path.is_empty():
			u.state = "idle"
	if services.movement._follow(u, delta):
		u.state = "idle"

func _step_join(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["command_groups", "interaction_paths", "officer_teams", "battle_simulation", "movement"])
	if services.is_empty(): return
	var leader: Dictionary = {}
	for candidate in battle.units:
		if int(candidate.uid) == int(u.get("join_target_uid", -1)): leader = candidate; break
	if leader.is_empty() or not bool(leader.alive) or leader.die_t >= 0 or leader.get("officer", {}).is_empty() or int(leader.owner) != int(u.owner):
		services.command_groups._cancel_unit_command(u)
	elif services.interaction_paths._edge_cell_distance(u, leader) <= Config.EDGE_DISTANCE:
		var idx := int(leader.officer.index)
		var members: Array = battle.units.filter(func(member): return bool(member.alive) and member.die_t < 0 and int(member.owner) == int(u.owner) and int(member.get("group_officer", -1)) == idx)
		services.command_groups._cancel_unit_command(u)
		if members.size() < Balance.team_max_members():
			u.group_officer = idx
			services.officer_teams._auto_assign_new_team(idx)
			services.battle_simulation._feedback("已加入%s的队伍" % str(leader.officer.name).replace(" ", ""))
		else: services.battle_simulation._feedback("该队伍已满15名成员")
	else:
		if u.path.is_empty(): u.path = services.interaction_paths._edge_interaction_path(u, leader); u.pi = 0
		if u.path.is_empty(): services.command_groups._cancel_unit_command(u); services.battle_simulation._feedback("无法靠近该队伍")
		else: services.movement._follow(u, delta)

func _step_board(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["battle_simulation", "movement", "transport_orders"])
	if services.is_empty(): return
	# 装载（模式 0xC）：走到运输船旁 → 附着上船（船计数 +1、HP 累加）。
	var bship = u.get("board_target", null)
	if not (bship is Dictionary) or not battle.transports.valid_ship(bship) or str(bship.state)=="unload" \
			or int(bship.get("unit", -1)) != Roles.transport_id() \
			or int(bship.get("owner", -1)) != int(u.get("owner", -1)):
		u.state = "idle"; u.board_target = null
	elif int(bship.get("carry_n", 0)) >= Balance.transport_capacity():
		u.state = "idle"; u.board_target = null
		services.battle_simulation._feedback("运输船已满（%d）" % Balance.transport_capacity())
	elif not battle.transports.adjacent(u,bship):
		if u.path.is_empty():
			u.path = battle.transports.boarding_path(u,bship); u.pi = 0
		if u.path.is_empty():
			u.state = "idle"; u.board_target = null; services.battle_simulation._feedback("无法靠近运输船")
		else: services.movement._follow(u, delta)
	else:
		u.path = []
		services.transport_orders._attach_to_ship(u, bship)

func _step_gather(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["interaction_paths", "battle_simulation", "movement"])
	if services.is_empty(): return
	var obj = u.get("gather_obj", null)
	if not (obj is Dictionary) or obj.is_empty():
		u.state = "idle"; u.path = []
	elif not bool(obj.get("alive", false)) or float(obj.get("die_t", -1)) >= 0:
		battle.harvesting.next_target(u, obj)
	elif services.interaction_paths._edge_cell_distance(u, obj) != Config.EDGE_DISTANCE:
		if u.path.is_empty():
			var choice: Dictionary = services.interaction_paths._edge_interaction_choice(u, obj)
			if not choice.is_empty():
				u.gather_obj = choice.object
				u.path = choice.path
			u.pi = 0
		if u.path.is_empty():
			u.state = "idle"; services.battle_simulation._feedback("工人无法到达该资源点边缘")
		else: services.movement._follow(u, delta)
	else:
		u.path = []
		battle.harvesting.extract(u, obj)

func _step_deliver(u: Dictionary, delta: float) -> bool:
	var services := ports.acquire(["harvest_orders", "interaction_paths", "battle_simulation", "movement"])
	if services.is_empty(): return false
	var deposits: Array = services.harvest_orders._deposits_for(u, str(u.get("carry_kind", "")))
	var arrived: Dictionary = {}
	for building in deposits:
		if services.interaction_paths._deposit_ready(u, building):
			arrived = building; break
	if not arrived.is_empty():
		u.delivery_ticks = int(u.get("delivery_ticks", 0)) + 1
		if int(u.delivery_ticks) % 4 != 0: return false
		if services.harvest_orders._deposit_carry(u):
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
				u.path = services.interaction_paths._edge_interaction_path(u, building, {}, Config.DEPOSIT_EDGE_PX); u.pi = 0
				if not u.path.is_empty(): break
		if u.path.is_empty():
			u.state = "idle"; services.battle_simulation._feedback("没有可到达的卸货建筑，工人保留携带资源")
		else: services.movement._follow(u, delta)
	return true

func _step_rest(u: Dictionary, delta: float) -> void:
	# 休息（模式 4，FUN_004602e0）：每 REST_TICKS 个逻辑 tick HP +1，满编即结束。
	if float(u.hp) >= float(u.maxhp) - 0.001:
		u.state = "idle"; u.rest_t = 0
	else:
		u.rest_t = int(u.get("rest_t", 0)) + 1
		if int(u.rest_t) >= int(Balance.work().restTicks):
			u.rest_t = 0
			u.hp = minf(float(u.maxhp), float(u.hp) + float(Balance.work().restHp))
		if float(u.hp) >= float(u.maxhp):
			u.state = "idle"; u.rest_t = 0

func _step_repair(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["spatial_index", "command_groups", "battle_simulation", "interaction_paths", "movement", "construction_orders"])
	if services.is_empty(): return
	var rt = u.get("repair_target",null)
	if not (rt is Dictionary) or not rt.get("alive",false) or float(rt.get("die_t",-1)) >= 0 or rt.get("attached",false) or int(rt.owner) != int(u.owner) or not services.spatial_index._contains_unit(rt):
		services.command_groups._cancel_unit_command(u)
	elif float(rt.hp) >= float(rt.maxhp):
		services.command_groups._cancel_unit_command(u)
	elif not battle.economy.can_pay(int(u.owner),Balance.work().repairCost):
		services.command_groups._cancel_unit_command(u); services.battle_simulation._feedback("修理：四种资源都须多于15")
	elif services.interaction_paths._dist_to_obj(u,rt) > Config.GATHER_REACH:
		preload("res://simulation/systems/action_clock.gd").reset(u)
		if u.path.is_empty(): u.path = services.interaction_paths._interaction_path(u,rt,Config.GATHER_REACH); u.pi = 0
		if u.path.is_empty(): services.command_groups._cancel_unit_command(u); services.battle_simulation._feedback("工人无法到达该修理目标")
		else: services.movement._follow(u,delta)
	else:
		u.path = []
		var offset := Vector2(rt.ax-u.ax,rt.ay-u.ay)
		u.dir = int(round(offset.angle()/(PI/4.0))) & 7
		if preload("res://simulation/systems/action_clock.gd").step(u,"repair",int(rt.uid)):
			if not services.construction_orders._do_repair(u,rt) or float(rt.hp) >= float(rt.maxhp): services.command_groups._cancel_unit_command(u)

func _step_build(u: Dictionary, delta: float) -> void:
	var services := ports.acquire(["construction_orders", "interaction_paths", "battle_simulation", "movement"])
	if services.is_empty(): return
	# 建造（模式 8，FUN_0045c320）：走到工地旁，**每 4 tick 给工地 +2 HP**（多工人叠加）。
	var bt = u.get("build_target", null)
	if not (bt is Dictionary) or not services.construction_orders._valid_build_worker(u, bt):
		u.state = "idle"; u.build_target = null; u.build_t = 0
	elif services.interaction_paths._edge_cell_distance(u, bt) != Config.EDGE_DISTANCE:
		if u.path.is_empty():
			u.path = services.construction_orders._site_entry_path(u, bt); u.pi = 0
		if u.path.is_empty():
			u.state = "idle"; u.build_target = null; u.build_t = 0; services.battle_simulation._feedback("工人无法到达工地")
		else: services.movement._follow(u, delta)
	else:
		battle.construction.enter(u, bt)

func _step_attack(u: Dictionary,delta: float,tower: bool) -> void:
	var services := ports.acquire(["spatial_index", "command_groups", "combat", "movement"])
	if services.is_empty(): return
	var phase:=ProfileClock.now(profile_enabled)
	var raw_target = u.target
	if not (raw_target is Dictionary) or not raw_target.alive or raw_target.die_t >= 0 or raw_target.get("attached",false) or not services.spatial_index._contains_unit(raw_target):
		services.command_groups._cancel_unit_command(u)
	else:
		if profile_enabled:phase=_profile_time("validTarget",phase)
		var t: Dictionary=raw_target
		var attack_range: float=preload("res://simulation/systems/combat_rules.gd").effective_range(u)
		var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
		var prepared: int
		if kernel!=null:prepared=kernel.prepare_combat(u,t,attack_range,battle.tile_w,tower,battle.nav.native_query_context())
		else:prepared=preload("res://simulation/systems/action_clock.gd").prepare_attack_script(u,t,attack_range,battle.tile_w,tower)
		var strike: bool=(prepared&1)!=0
		if profile_enabled:phase=_profile_time("clock",phase)
		var in_reach: bool=(prepared&2)!=0
		# 近战按**近距离格**判定：不叠格后，等距邻格/斜邻格的脚点距离可到 66px，
		# 仍应视为贴脸可攻击（否则会被前面的单位卡在 66px 外）。
		# R06：放宽到两格时必须同时确认中间没有墙/不可通行地形/封闭建筑，
		# 否则会“隔墙扣血”。远程越墙仍走独立规则（不在此补偿内）。
		if attack_range <= 1 and kernel==null:
			if not in_reach:
				var uc: Vector2i = services.spatial_index._unit_cell(u);var tc: Vector2i = services.spatial_index._unit_cell(t)
				in_reach=maxi(absi(uc.x-tc.x),absi(uc.y-tc.y))<=2
			in_reach=in_reach and services.combat._melee_line_clear(u,t)
		if profile_enabled:phase=_profile_time("contact",phase)
		if in_reach:
			u.route_failures=0
			u.path = []; u.pi = 0
			if strike:
				services.combat._fire_attack(u,t)
		elif tower:
			services.command_groups._cancel_unit_command(u)
		else:
			if strike: preload("res://simulation/systems/action_clock.gd").reset(u) # 击发时射程失效，重发同一攻击重新等待。
			u.repath -= delta
			if u.repath <= 0:
				_repath_attack(u,t,attack_range)
			services.movement._follow(u,delta)

	if profile_enabled:phase=_profile_time("hitOrFollow",phase)

func _repath_attack(u: Dictionary,t: Dictionary,attack_range: float) -> void:
	var services := ports.acquire(["interaction_paths", "movement"])
	if services.is_empty(): return
	# 近战不能把“敌方占格”当终点（不叠格会停在两格外），
	# 改寻到目标占格旁的落脚格；远程仍寻到目标本身。
	if attack_range <= 1:
		u.path = services.interaction_paths._edge_interaction_path(u, t)
	else:
		u.path = services.movement._path_to(u,Vector2(t.ax,t.ay),false)
	u.pi = 0
	u.route_failures=mini(3,int(u.get("route_failures",0))+1) if u.path.is_empty() else 0
	# Stable UID phases spread synchronized retry bursts without using
	# wall time or RNG; the remaining delay is saved with the order.
	u.repath=0.8*pow(2.0,maxi(0,int(u.route_failures)-1))+(int(u.uid)%11)*Config.SIM_DT

func _try_native_attack(u: Dictionary,delta: float,kernel: Object) -> bool:
	var services := ports.acquire(["combat", "movement", "spatial_index"])
	if services.is_empty(): return false
	if u.state!="attack" or bool(u.is_building):return false
	var at:=ProfileClock.now(profile_enabled)
	var result: int=kernel.attack_fast(u,delta,battle.nav.native_query_context(),battle._target_owner,battle._targets,battle.units,battle._index_units_ref,battle._index_units_size)
	if profile_enabled:at=_profile_time("nativePrepare",at)
	if result<0:return false
	if result&1:services.combat._fire_attack(u,u.target)
	if result&2:_repath_attack(u,u.target,float(u.atk_range))
	if result&4:services.movement._follow(u,delta)
	u.anim+=delta
	if profile_enabled:at=_profile_time("nativeApply",at)
	if kernel.finish_or_separate(u,battle._cell_index,battle.nav.native_query_context()):
		services.spatial_index._separate_unit(u)
		kernel.finish_plain_attack(u)
	if profile_enabled:_profile_time("nativeFinalize",at)
	return true
