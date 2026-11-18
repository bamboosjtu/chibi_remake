extends RefCounted
## battle simulation: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const ProfileClock = preload("res://simulation/definitions/profile_clock.gd")
const Dependencies = preload("res://simulation/ports/battle_simulation_dependencies.gd")
var battle: State
var ports := Dependencies.new()
var tick_microseconds := 0
var profile_enabled := false
var timing_enabled := false
var profile: Dictionary={}
var native_unit_profile: Dictionary={}
var native_unit_port: Object

func _init(data: State) -> void:
	battle = data

func _feedback(msg: String) -> void:
	battle.effects.visual("feedback", [msg])

func _resources() -> Dictionary:
	return {"gold": battle.gold, "wood": battle.wood, "food": battle.food, "stone": battle.stone}

func set_sim_speed(index: int) -> bool:
	var previous: float = battle.clock.period()
	if not battle.clock.set_speed(index): return false
	battle.sim_acc *= battle.clock.period()/previous # 换档保留当前tick已走过的比例。
	_feedback("游戏速度：%s" % battle.clock.label())
	return true

func _place_unit(u: Dictionary) -> void:
	ports._index_sync(u)                 # R13：占格索引跟随真实位置
	ports._target_sync(u)                # 存活/装载变化同步索敌桶
	if battle.effects != null:
		battle.effects.visual("place_unit", [u])

func _fade_unit(u: Dictionary, alpha: float) -> void:
	if battle.effects != null:
		battle.effects.visual("fade_unit", [u, alpha])

func _finish_death(u: Dictionary) -> void:
	u.alive = false
	# 主将阵亡：部队自动解散，并把已失效的编队槽一起清掉，避免呼出只剩工人。
	if not (u.get("officer", {}) as Dictionary).is_empty():
		_clear_control_group_for(int(u.uid))
		ports._unassign_officer(u)
	if battle.effects != null:
		battle.effects.visual("hide_unit", [u])
	battle.selected.erase(u)

func _clear_officer_control_groups(officer_index:int, owner:int, leader_uid:int) -> void:
	var released:Dictionary={leader_uid:true}
	for member in battle.units:
		if int(member.owner)==owner and int(member.get("group_officer",-1))==officer_index:released[int(member.uid)]=true
	for slot in battle.control_groups.keys():
		var kept:Array=[]
		for uid in battle.control_groups[slot]:
			if not released.has(int(uid)):kept.append(int(uid))
		if kept.is_empty():battle.control_groups.erase(slot)
		else:battle.control_groups[slot]=kept

func _clear_control_group_for(uid: int) -> void:
	for n in battle.control_groups.keys():
		if (battle.control_groups[n] as Array).has(uid):
			battle.control_groups.erase(n)

func _update_gates() -> void:
	battle.automatic_gates.update(battle.nav, battle.units)

func _sim_step(dt: float) -> void:
	if battle.game_end != 0: return
	var tick_begin:=ProfileClock.now(profile_enabled or timing_enabled)
	var phase:=tick_begin
	if battle.effects!=null:battle.effects.simulating=true
	if battle.effects != null:battle.effects.visual("capture_motion", [])
	battle.visibility.update(battle.units, battle.player_owner)
	if profile_enabled:phase=_profile_time("visibilityBegin",phase)
	battle.sim_tick += 1
	battle.player_commands.apply_tick(battle.sim_tick)
	ports._step_auto_control()
	battle.projectiles.step() # 本tick新击发的弹体从下一个逻辑tick推进。
	if profile_enabled:phase=_profile_time("projectiles",phase)
	if battle.ai != null:
		battle.ai.tick()
	if profile_enabled:phase=_profile_time("ai",phase)
	ports._process_trainings(dt)
	ports._process_tech(dt)
	_update_gates()
	if profile_enabled:phase=_profile_time("production",phase)
	_step_units(dt)
	if profile_enabled:phase=_profile_time("units",phase)
	battle.fire_fields.step() # Effects follow unit updates; damage always uses current cell occupants.
	ports._process_sites(dt)
	ports._process_officer_recovery()
	if profile_enabled:phase=_profile_time("effectsSitesRecovery",phase)
	battle.transports.reconcile()
	if profile_enabled:phase=_profile_time("transports",phase)
	_prune_dead()
	battle.visibility.update(battle.units, battle.player_owner)
	if profile_enabled:phase=_profile_time("visibilityEnd",phase)
	ports._check_end()
	if battle.effects!=null:
		battle.effects.simulating=false
		battle.effects.visual("world_dirty")
	if profile_enabled:_profile_time("settlement",phase)
	tick_microseconds+=ProfileClock.now(profile_enabled or timing_enabled)-tick_begin


func connect_native() -> void:
	disconnect_native()
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel(true)
	if kernel==null:return
	var abort:=preload("res://composition_contract.gd").abort_if_broken.bind("native unit commands",[{"provider":"native unit commands","method":"provider lifetime"}])
	native_unit_port=kernel.make_unit_port(ports._fire_attack,ports._repath_attack,ports._follow,ports._separate_unit,ports._step_unit,ports._die_step,battle.nav.native_query_context,abort)

func disconnect_native() -> void:
	if native_unit_port!=null:native_unit_port.release_commands()
	native_unit_port=null

func _step_units(dt: float) -> void:
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null and native_unit_port!=null:
		var counters: Dictionary=kernel.step_units(battle.units,dt,battle.nav.native_query_context(),battle._target_owner,battle._targets,battle._cell_index,battle._index_units_ref,battle._index_units_size,native_unit_port,profile_enabled)
		if profile_enabled:
			for key in counters:native_unit_profile[key]=int(native_unit_profile.get(key,0))+int(counters[key])
		return
	for u: Dictionary in battle.units:
		if not u.alive:
			continue
		if u.die_t >= 0.0:
			ports._die_step(u, dt)
			continue
		if not u.is_building or int(u.unit) in [18,19]:
			ports._step_unit(u, dt)

func _state_digest() -> int:
	var h := 1469598103934665603
	for u in battle.units:
		h = (h ^ int(u.uid)) * 1099511628211
		h = (h ^ int(u.unit)) * 1099511628211
		h = (h ^ int(u.owner)) * 1099511628211
		h = (h ^ int(round(u.ax))) * 1099511628211
		h = (h ^ int(round(u.ay))) * 1099511628211
		h = (h ^ int(round(u.hp))) * 1099511628211
		h = (h ^ (1 if u.alive else 0)) * 1099511628211
	return absi(h)

func _prune_dead() -> void:
	var i := battle.units.size() - 1
	while i >= 0:
		if not (battle.units[i] as Dictionary).alive:
			_free_unit_at(i)
		i -= 1

func _free_unit_at(i: int) -> void:
	if i < 0 or i >= battle.units.size(): return
	var u: Dictionary = battle.units[i]
	if u.has("occupied_cells"):
		battle.nav.occupy(u.occupied_cells, -1)
	ports._index_forget(u)
	ports._target_forget(u)
	battle._foot_cache.erase(int(u.get("uid", -1)))
	if battle.effects != null:
		battle.effects.visual("free_unit", [u])
	battle.selected.erase(u)
	battle.units.remove_at(i)
	battle._index_units_size = battle.units.size()

func _update_visual(u: Dictionary) -> void:
	battle.effects.visual("update_visual", [u])

func _set_frame(u: Dictionary, f: int) -> void:
	battle.effects.visual("set_frame", [u, f])

func _profile_time(key: String, at: int) -> int:
	var now:=ProfileClock.now(profile_enabled);profile[key]=int(profile.get(key,0))+now-at;return now
