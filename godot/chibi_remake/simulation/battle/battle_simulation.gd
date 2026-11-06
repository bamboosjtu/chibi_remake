extends RefCounted
## battle simulation: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Dependencies = preload("res://simulation/ports/battle_simulation_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _feedback(msg: String) -> void:
	battle.feedback_text = msg
	battle.feedback_until = Time.get_ticks_msec() + 2500

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
	if battle.effects != null:battle.effects.visual("capture_motion", [])
	battle.visibility.update(battle.units, battle.player_owner)
	battle.sim_tick += 1
	ports._step_auto_control()
	battle.projectiles.step() # 本tick新击发的弹体从下一个逻辑tick推进。
	if battle.ai != null:
		battle.ai.tick()
	ports._process_trainings(dt)
	ports._process_tech(dt)
	_update_gates()
	for u in battle.units:
		if not u.alive:
			continue
		if u.die_t >= 0.0:
			ports._die_step(u, dt)
			continue
		if not u.is_building or int(u.unit) in [18,19]:
			ports._step_unit(u, dt)
		_update_visual(u)
	battle.fire_fields.step() # Effects follow unit updates; damage always uses current cell occupants.
	ports._process_sites(dt)
	ports._process_officer_recovery()
	battle.transports.reconcile()
	_prune_dead()
	battle.visibility.update(battle.units, battle.player_owner)
	ports._check_end()

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
