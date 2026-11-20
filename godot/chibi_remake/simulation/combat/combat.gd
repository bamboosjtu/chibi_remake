extends Object
const VisibilityRuntime = preload("res://simulation/visibility/battle_visibility.gd")
var _visibility: VisibilityRuntime
var _transports: RefCounted
var _projectiles: RefCounted
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
var _construction: RefCounted
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## combat: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_abilities: Object
var _dep_battle_simulation: Object
var _dep_command_groups: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
var _dep_officer_teams: Object
var _dep_production: Object
var _dep_spatial_index: Object
var _dep_technology: Object
var _contact_cache: Dictionary={}

func _init(data: State) -> void:
	battle = data

func _damage(a: Dictionary, d: Dictionary) -> float:
	return preload("res://simulation/definitions/combat_rules.gd").damage(a, d, Roles.uses_channel_b(int(a.get("unit", -1))))

func _fire_attack(attacker: Dictionary, target: Dictionary) -> void:
	if _effects != null and (int(attacker.get("owner", -1)) == battle.player_owner or _visibility.is_visible(Vector2(float(attacker.ax), float(attacker.ay)))):
		_effects.sound("play_attack", [attacker])
	var kind := int(attacker.unit)
	if preload("res://simulation/definitions/combat_rules.gd").ambush(attacker):_projectiles.launch(attacker,target,"ambush")
	elif kind == 34: _projectiles.launch(attacker,target,"stone")
	elif Roles.uses_channel_b(kind): _projectiles.launch(attacker,target,"arrow")
	else: _apply_hit(target,_damage(attacker,target),int(attacker.uid))

func _apply_hit(target: Dictionary, damage: float, source_uid: int) -> void:
	if int(target.get("site_inside_uid", -1)) >= 0: return
	if not target.get("alive",false) or float(target.get("die_t",-1)) >= 0 or target.get("attached",false): return
	if battle.cheat_invulnerable and int(target.owner) == battle.player_owner: return
	target.hp -= damage; target["last_attacker_uid"] = source_uid
	if target.hp < 1:
		_kill(target,_dep_spatial_index.unit_by_uid(source_uid))

func _projectile_arrived(effect: Dictionary) -> void:
	if effect.kind in ["arrow","ambush"]:
		var target: Dictionary = _dep_spatial_index.unit_by_uid(int(effect.targetUid))
		if not target.is_empty(): _apply_hit(target,float(effect.damage),int(effect.sourceUid))
	else:
		var cell := Vector2i(int(effect.a),int(effect.b))
		for target in battle.units:
			if not target.alive or target.die_t >= 0 or target.get("attached",false): continue
			if _dep_movement._cell_of_px(target.ax,target.ay) != cell and cell not in target.get("occupied_cells",[]): continue
			var defence := roundi(preload("res://simulation/definitions/combat_rules.gd").defence(target,true)*100.0)
			var damage := float(maxi(1,int(float(int(effect.attackCents)-defence)/100.0)))
			_apply_hit(target,damage,int(effect.sourceUid)); break
		_effects.visual("impact", [Vector2(effect.tx,effect.ty)])

func _hostile_owners(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b: return false
	return a == battle.player_owner or b == battle.player_owner

## R09：只与玩家方敌对；参数已精简，调用方不再需要区分“仅人类战场”。
func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d * max_d
	var ux: float = u.ax
	var uy: float = u.ay
	var my_owner := int(u.owner)
	var player_side := my_owner == battle.player_owner
	_dep_spatial_index._index_ensure_current()
	for owner_key in battle._targets:
		var owner := int(owner_key)
		if owner == my_owner or owner == 0:
			continue
		if not _hostile_owners(my_owner, owner):
			continue                    # AI 只与玩家为敌（R09）
		var bucket: Dictionary = battle._targets[owner_key]
		for e in bucket.values():
			var dx: float = e.ax - ux
			var dy: float = e.ay - uy
			var d2: float = dx * dx + dy * dy
			if d2 >= bd: continue
			if not e.alive or e.die_t >= 0.0 or bool(e.get("attached", false)): continue
			# Direct fixture/event edits may leave ownership out of sync with its bucket.
			if int(e.owner) != owner and not _hostile_owners(my_owner, int(e.owner)): continue
			if player_side and not _visibility.is_visible(Vector2(e.ax, e.ay)): continue
			if d2 < bd:
				bd = d2
				best = e
	return best

func _melee_line_clear(a: Dictionary, b: Dictionary) -> bool:
	var from:=Vector2(float(a.ax),float(a.ay));var to:=Vector2(float(b.ax),float(b.ay))
	var positions:=PackedFloat64Array([float(a.ax),float(a.ay),float(b.ax),float(b.ay)])
	var identity:=Vector3i(int(b.uid),int(a.unit),int(b.unit))
	var version: int=_nav.version;var uid:=int(a.uid)
	var previous=_contact_cache.get(uid)
	# Layer is a function of type and this navigation revision. Resolve the
	# port and endpoint footprints only on a cache miss, never on a stable hit.
	if previous!=null and previous.version==version and previous.identity==identity and previous.positions==positions:return bool(previous.clear)
	var ignore: Dictionary={}
	for cell in _dep_interaction_paths._footprint_cells(a):ignore[cell]=true
	for cell in _dep_interaction_paths._footprint_cells(b):ignore[cell]=true
	var clear: bool=_nav.contact_clear(from,to,ignore,_dep_command_groups._nav_layer(a))
	_contact_cache[uid]={"positions":positions,"identity":identity,"version":version,"clear":clear}
	return clear

func officer_rank_name(off: Dictionary) -> String:
	return str(preload("res://simulation/officers/officer_progression.gd").cell(off).rank)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	if u.die_t >= 0 or not u.alive: return
	_contact_cache.erase(int(u.uid))
	if by.is_empty():
		for attacker in battle.units:
			if int(attacker.uid)==int(u.get("last_attacker_uid",-1)):by=attacker;break
	# R07：待确认的施法不能留给尸体；死亡动画期间 alive 仍为 true。
	if is_same(battle.jimou_caster, u):
		_dep_abilities._reset_jimou()
	# 同步移除失效引用，避免暂停在死亡当tick后保存出悬空研究订单。
	if u.is_building:
		_dep_technology.cancel_destroyed_building(int(u.uid))
		_dep_production.cancel_destroyed_building(u)
	if int(u.unit) in [16, 17]: _nav.remove_gate(u)
	# 运输船被击沉：船上的被载单位一并死亡/移除（原版：船失效 → 被载单位收模式 0x12）。
	if int(u.get("unit", -1)) == Roles.transport_id():
		for p in _transports.passengers(u): _kill(p, by)
		u["carry_n"] = 0
		u["carry_hp"] = 0.0
		u["loaded"] = false
	if bool(u.get("attached",false)):
		var carrier: Dictionary=_transports.ship_for(u)
		if not carrier.is_empty():
			u.ax=float(carrier.ax);u.ay=float(carrier.ay);u.A=int(carrier.A);u.B=int(carrier.B)
			carrier.carry_n=maxi(0,int(carrier.carry_n)-1)
			carrier.carry_hp=maxf(0,float(carrier.carry_hp)-float(u.hp));carrier.loaded=int(carrier.carry_n)>0
		u.aboard_uid=-1 # 仍隐藏至死亡清理；不留指向已移除船的悬空引用。
	# 原版 FUN_00422a20 击杀结算（2026-10-16 REA）：
	#   击杀方士气 += 兵种[+0x35]、经验 += 兵种[+0x34]（计入所辖将），被杀方 -士气；
	#   大旗（26）被毁 → 该方全体士气 -50。
	var victim_commander: Dictionary = _dep_command_groups._commander_for(u)
	if not by.is_empty() and bool(by.get("alive", false)):
		var commander: Dictionary = _dep_command_groups._commander_for(by)
		var reward: Dictionary=preload("res://simulation/officers/officer_progression.gd").reward(int(u.unit))
		_dep_officer_teams._grant_officer_exp(by,float(reward.killXp))
		if not commander.is_empty(): commander.status_173 = (int(commander.status_173) + int(reward.morale)) & 255
		if not victim_commander.is_empty(): victim_commander.status_173 = (int(victim_commander.status_173) - int(reward.morale)) & 255
	if int(u.unit) == 26:
		for other in battle.units:
			if int(other.owner) == int(u.owner) and not other.get("officer", {}).is_empty(): other.status_173 = (int(other.status_173) - 50) & 255
	# 原版 FUN_00443020：HP 归零即释放该武将（清 DAT_004ae128[o*0x2c]），
	# 于是这个武将可以再被"组建"到别的部队上。
	if not (u.get("officer", {}) as Dictionary).is_empty():
		_dep_officer_teams._unassign_officer(u)
	u.die_t = 0.0
	if u.is_building: _construction.release_site(u)
	u.state = "dead"
	u.target = null
	_dep_spatial_index._index_forget(u)               # R13：尸体不再阻挡落点/不再被索敌
	_dep_spatial_index._target_forget(u)
	battle.selected.erase(u)

func _die_step(u: Dictionary, delta: float) -> void:
	u.die_t += delta
	var rule = preload("res://simulation/definitions/timing/death_visual.gd")
	var frame: int = rule.frame(u,float(u.die_t))
	if frame < 0:
		_dep_battle_simulation._finish_death(u); return
	_dep_battle_simulation._set_frame(u,frame)
	_dep_battle_simulation._fade_unit(u,rule.alpha(u,float(u.die_t)))

func _clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	return preload("res://simulation/combat/animation_rules.gd").clip_dir(u, clip, dir)

func _clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	return preload("res://simulation/combat/animation_rules.gd").clip_frame(u, clip, dir, step)

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_battle_simulation = world.battle_simulation
	_dep_command_groups = world.command_groups
	_dep_interaction_paths = world.interaction_paths
	_dep_movement = world.movement
	_dep_officer_teams = world.officer_teams
	_dep_production = world.production
	_dep_spatial_index = world.spatial_index
	_dep_technology = world.technology
	_construction = world.construction
	_effects = world.effects
	_nav = world.nav
	_projectiles = world.projectiles
	_transports = world.transports
	_visibility = world.visibility
