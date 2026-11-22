extends Object
const CombatState = preload("res://simulation/combat/combat_state.gd")
const ManifestState = preload("res://simulation/transport/manifest_state.gd")
const UnitMotion = preload("res://simulation/movement/unit_motion.gd")
const UnitPath = preload("res://simulation/movement/unit_path.gd")
var _transports: RefCounted
var _stratagems: RefCounted
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
var _harvesting: RefCounted
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _economy: RefCounted
var _construction: RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## unit actions: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
const ProfileClock = preload("res://simulation/core/profile_clock.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
var battle: State
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_construction_orders: Object
var _dep_harvest_orders: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
var _dep_officer_teams: Object
var _dep_spatial_index: Object
var _dep_transport_orders: Object
const Lifecycle = preload("res://simulation/units/unit_lifecycle.gd")
var _lifecycle := Lifecycle.new()
var profile_enabled := false
var profile: Dictionary={}

func _init(data: State) -> void:
	battle = data

func _step_unit(u: Dictionary, delta: float, native_attack_checked := false) -> void:
	if profile_enabled:
		_step_unit_profiled(u, delta, native_attack_checked)
		return
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if not native_attack_checked and kernel != null and u.state == "attack" and not u.is_building:
		if _dep_combat.try_native_attack(u, delta, kernel): return
	preload("res://simulation/combat/stratagem_rules.gd").begin_update(u)
	_step_unit_inner(u, delta)
	_dep_spatial_index._separate_unit(u)
	_stratagems.step_effects(u)
	if kernel!=null:kernel.finish_unit(u)
	else:
		preload("res://simulation/movement/locomotion.gd").step_script(u)
		preload("res://simulation/movement/tick_timers.gd").step_statuses_script(u)

func _step_unit_profiled(u: Dictionary, delta: float, native_attack_checked: bool) -> void:
	var at:=ProfileClock.now(profile_enabled)
	var kernel:=preload("res://simulation/native/math_kernel.gd").get_kernel()
	if not native_attack_checked and kernel != null and u.state == "attack" and not u.is_building:
		if _dep_combat.try_native_attack(u, delta, kernel):
			_profile_time("nativeAttack", at)
			profile["units"] = int(profile.get("units", 0)) + 1
			return
	preload("res://simulation/combat/stratagem_rules.gd").begin_update(u);at=_profile_time("beginStatus",at)
	_step_unit_inner(u,delta);var end:=ProfileClock.now(profile_enabled)
	var key: String="kind%d" % int(u.unit);profile[key]=int(profile.get(key,0))+end-at
	at=_profile_time("action",at)
	_dep_spatial_index._separate_unit(u);at=_profile_time("separation",at)
	_stratagems.step_effects(u);at=_profile_time("effects",at)
	preload("res://simulation/movement/locomotion.gd").step(u);at=_profile_time("locomotion",at)
	preload("res://simulation/movement/tick_timers.gd").step_statuses(u);_profile_time("timers",at)
	profile["units"]=int(profile.get("units",0))+1

func _profile_time(key: String, at: int) -> int:
	var now:=ProfileClock.now(profile_enabled);profile[key]=int(profile.get(key,0))+now-at;return now


func _step_unit_inner(u: Dictionary, delta: float) -> void:
	var phase := ProfileClock.now(profile_enabled)
	if not _prepare_action(u, delta): return
	if profile_enabled: _profile_time("prepare", phase)
	match str(u.state):
		"attack": _dep_combat.step_attack(u, delta, _is_tower(u))
		"move": _dep_movement.step_action(u, delta)
		"join": _dep_officer_teams.step_join(u, delta)
		"board": _transports.step_board(u, delta)
		"gather": _harvesting.step_gather(u, delta)
		"deliver":
			# Delivery waits deliberately skip animation, as in the original tick.
			if not _harvesting.step_deliver(u, delta): return
		"rest": _lifecycle._step_rest(u, delta)
		"repair": _dep_construction_orders.step_repair(u, delta)
		"build": _dep_construction_orders.step_build(u, delta)
	# Idle, unload and passive states share the same final animation step.
	UnitMotion.add_to_anim(u, delta)

func _is_tower(u: Dictionary) -> bool:
	return bool(u.is_building) and int(u.unit) in [18,19]

func _prepare_action(u: Dictionary, delta: float) -> bool:
	UnitMotion.set_moved(u, false)
	if bool(u.get("attached", false)):
		return false
	# Confusion/rolling idle tasks wait behind the running order, without clearing it.
	if preload("res://simulation/combat/stratagem_rules.gd").active(u):
		UnitMotion.add_to_anim(u, delta)
		return false
	if (int(u.get("site_inside_uid",-1))>=0 or int(u.get("site_follow_uid",-1))>=0) and _construction.step(u): return false
	# 下船按每 4 拍一名推进；船接到新命令也不打断在舱载员的卸载。
	if (bool(u.get("unload_active", false)) or str(u.get("state", "")) == "unload") and int(u.get("unit", -1)) == Roles.transport_id():
		ManifestState.set_unload_t(u, int(u.get("unload_t", 0)) + 1)
		if int(u.unload_t) % 4 == 0:
			_dep_transport_orders._retry_unload(u)
		if int(u.get("carry_n", 0)) <= 0:
			ManifestState.set_unload_active(u, false)
			if str(u.get("state", "")) == "unload": u.state = "idle"
	# 旧存档或旧AI可能留下无武装单位的攻击命令；执行层同样拒绝。
	if u.state == "attack" and not preload("res://simulation/definitions/combat_rules.gd").can_attack(u):
		_dep_command_groups._cancel_unit_command(u)
	# 遭遇接战不受战略 AI 的出兵科技/金钱条件限制；忙碌与原地待命单位保留命令。
	if u.state=="idle":preload("res://simulation/combat/engagement.gd").step(battle, u, _dep_combat._nearest_enemy)
	# 箭楼独立守卫，AI之间不互相射击。
	var tower := _is_tower(u)
	if tower and u.state == "idle" and not bool(u.get("site", false)) and int(u.get("confused_t", 0)) <= 0:
		var enemy: Dictionary = _dep_combat._nearest_enemy(u, float(u.atk_range) * battle.tile_w)
		if not enemy.is_empty():
			CombatState.set_target(u, enemy); u.state = "attack"
	if u.state == "idle" and not bool(u.get("hold", false)) and not (u.get("officer", {}) as Dictionary).is_empty():
		_follow_working_members(u)
	return true

func _follow_working_members(u: Dictionary) -> void:
	# 带将部队的将本体在空闲时跟随正在干活/行军的成员，不把将留在原地。
	var leader_idx := int(u.officer.get("index", -1))
	for member in battle.units:
		if int(member.get("group_officer", -1)) != leader_idx: continue
		if is_same(member, u) or not bool(member.get("alive", false)) or float(member.get("die_t", -1)) >= 0.0: continue
		if str(member.get("state", "")) in ["move", "gather", "deliver", "build", "repair", "attack"]:
			var follow_to := Vector2(float(member.ax), float(member.ay))
			if Vector2(float(u.ax), float(u.ay)).distance_to(follow_to) > 2.0 * battle.tile_w:
				u.state = "move"
				UnitPath.set_points(u, _dep_movement._path_to(u, follow_to, true))
				UnitPath.reset_cursor(u)
				break

func bind_dependencies(world: Object) -> void:
	_dep_combat = world.combat
	_dep_command_groups = world.command_groups
	_dep_construction_orders = world.construction_orders
	_dep_harvest_orders = world.harvest_orders
	_dep_interaction_paths = world.interaction_paths
	_dep_movement = world.movement
	_dep_officer_teams = world.officer_teams
	_dep_spatial_index = world.spatial_index
	_dep_transport_orders = world.transport_orders
	_construction = world.construction
	_economy = world.economy
	_effects = world.effects
	_harvesting = world.harvesting
	_nav = world.nav
	_stratagems = world.stratagems
	_transports = world.transports
