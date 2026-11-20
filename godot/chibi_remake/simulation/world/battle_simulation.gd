extends Object
const VisibilityRuntime = preload("res://simulation/visibility/battle_visibility.gd")
var _visibility: VisibilityRuntime
var _transports: RefCounted
var _projectiles: RefCounted
var _player_commands: RefCounted
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
var _fire_fields: RefCounted
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
const ClockRuntime = preload("res://simulation/core/battle_clock.gd")
var _clock: ClockRuntime
const AutomaticGatesRuntime = preload("res://simulation/navigation/automatic_gates.gd")
var _automatic_gates: AutomaticGatesRuntime
var _ai: RefCounted
## battle simulation: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const ProfileClock = preload("res://simulation/core/profile_clock.gd")
var battle: State
var _dep_campaign: Object
var _dep_cheat_rules: Object
var _dep_combat: Object
var _dep_construction_orders: Object
var _dep_movement: Object
var _dep_officer_teams: Object
var _dep_production: Object
var _dep_spatial_index: Object
var _dep_technology: Object
var _dep_unit_actions: Object
var tick_microseconds := 0
var profile_enabled := false
var timing_enabled := false
var profile: Dictionary={}
var native_unit_profile: Dictionary={}
var native_unit_port: Object

func _init(data: State) -> void:
	battle = data

func set_sim_speed(index: int) -> bool:
	var previous: float = _clock.period()
	if not _clock.set_speed(index): return false
	battle.sim_acc *= _clock.period()/previous # 换档保留当前tick已走过的比例。
	_effects.feedback("游戏速度：%s" % _clock.label())
	return true

func _place_unit(u: Dictionary) -> void:
	_dep_spatial_index._index_sync(u)                 # R13：占格索引跟随真实位置
	_dep_spatial_index._target_sync(u)                # 存活/装载变化同步索敌桶
	if _effects != null:
		_effects.visual("place_unit", [u])

func _fade_unit(u: Dictionary, alpha: float) -> void:
	if _effects != null:
		_effects.visual("fade_unit", [u, alpha])

func _finish_death(u: Dictionary) -> void:
	u.alive = false
	# 主将阵亡：部队自动解散，并把已失效的编队槽一起清掉，避免呼出只剩工人。
	if not (u.get("officer", {}) as Dictionary).is_empty():
		_clear_control_group_for(int(u.uid))
		_dep_officer_teams._unassign_officer(u)
	if _effects != null:
		_effects.visual("hide_unit", [u])
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
	_automatic_gates.update(_nav, battle.units)

func _sim_step(dt: float) -> void:
	if battle.game_end != 0: return
	var tick_begin:=ProfileClock.now(profile_enabled or timing_enabled)
	var phase:=tick_begin
	if _effects!=null:_effects.simulating=true
	if _effects != null:_effects.visual("capture_motion", [])
	# Visibility is published once at the end of the tick. Map start, load and reveal
	# changes publish it themselves (battle_opening, snapshot_restorer, cheat_rules),
	# so a start-of-tick pass would only rescan the unchanged previous state.
	battle.sim_tick += 1
	_player_commands.apply_tick(battle.sim_tick)
	_dep_cheat_rules._step_auto_control()
	_projectiles.step() # 本tick新击发的弹体从下一个逻辑tick推进。
	if profile_enabled:phase=_profile_time("projectiles",phase)
	if _ai != null:
		_ai.tick()
	if profile_enabled:phase=_profile_time("ai",phase)
	_dep_production._process_trainings(dt)
	_dep_technology._process_tech(dt)
	_update_gates()
	if profile_enabled:phase=_profile_time("production",phase)
	_step_units(dt)
	if profile_enabled:phase=_profile_time("units",phase)
	_fire_fields.step() # Effects follow unit updates; damage always uses current cell occupants.
	_dep_construction_orders._process_sites(dt)
	_dep_officer_teams._process_officer_recovery()
	if profile_enabled:phase=_profile_time("effectsSitesRecovery",phase)
	_transports.reconcile()
	if profile_enabled:phase=_profile_time("transports",phase)
	_prune_dead()
	_visibility.update(battle.units, battle.player_owner)
	if profile_enabled:phase=_profile_time("visibilityEnd",phase)
	_dep_campaign._check_end()
	if _effects!=null:
		_effects.simulating=false
		_effects.visual("world_dirty")
	if profile_enabled:_profile_time("settlement",phase)
	tick_microseconds+=ProfileClock.now(profile_enabled or timing_enabled)-tick_begin


func connect_native() -> void:
	disconnect_native()
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel(true)
	if kernel==null:return
	var abort:=preload("res://composition_contract.gd").abort_if_broken.bind("native unit commands",[{"provider":"native unit commands","method":"provider lifetime"}])
	# The batch calls its fallback only when attack_fast has already rejected the unit.
	native_unit_port=kernel.make_unit_port(_dep_combat._fire_attack,_dep_unit_actions._repath_attack,_dep_movement._follow,_dep_spatial_index._separate_unit,_dep_unit_actions._step_unit.bind(true),_dep_combat._die_step,_nav.native_query_context,abort)

func disconnect_native() -> void:
	if native_unit_port!=null:native_unit_port.release_commands()
	native_unit_port=null

func _step_units(dt: float) -> void:
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if kernel!=null and native_unit_port!=null:
		var counters: Dictionary=kernel.step_units(battle.units,dt,_nav.native_query_context(),battle._target_owner,battle._targets,battle._cell_index,battle._index_units_ref,battle._index_units_size,native_unit_port,profile_enabled)
		if profile_enabled:
			for key in counters:native_unit_profile[key]=int(native_unit_profile.get(key,0))+int(counters[key])
		return
	for u: Dictionary in battle.units:
		if not u.alive:
			continue
		if u.die_t >= 0.0:
			_dep_combat._die_step(u, dt)
			continue
		if not u.is_building or int(u.unit) in [18,19]:
			_dep_unit_actions._step_unit(u, dt)

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
		_nav.occupy(u.occupied_cells, -1)
	_dep_spatial_index._index_forget(u)
	_dep_spatial_index._target_forget(u)
	battle._foot_cache.erase(int(u.get("uid", -1)))
	if _effects != null:
		_effects.visual("free_unit", [u])
	battle.selected.erase(u)
	battle.units.remove_at(i)
	battle._index_units_size = battle.units.size()

func _update_visual(u: Dictionary) -> void:
	_effects.visual("update_visual", [u])

func _set_frame(u: Dictionary, f: int) -> void:
	_effects.visual("set_frame", [u, f])

func _profile_time(key: String, at: int) -> int:
	var now:=ProfileClock.now(profile_enabled);profile[key]=int(profile.get(key,0))+now-at;return now

func bind_dependencies(world: Object) -> void:
	_dep_campaign = world.campaign
	_dep_cheat_rules = world.cheat_rules
	_dep_combat = world.combat
	_dep_construction_orders = world.construction_orders
	_dep_movement = world.movement
	_dep_officer_teams = world.officer_teams
	_dep_production = world.production
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_dep_unit_actions = world.unit_actions
	_automatic_gates = world.automatic_gates
	_clock = world.clock
	_effects = world.effects
	_fire_fields = world.fire_fields
	_nav = world.nav
	_player_commands = world.player_commands
	_projectiles = world.projectiles
	_transports = world.transports
	_visibility = world.visibility
