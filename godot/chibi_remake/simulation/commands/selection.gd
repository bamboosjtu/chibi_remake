extends Object
const VisibilityRuntime = preload("res://simulation/visibility/battle_visibility.gd")
var _visibility: VisibilityRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
## selection: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_harvest_orders: Object

func _init(data: State) -> void:
	battle = data

func _neutral_object_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for o in battle.units:
		if not bool(o.get("alive", false)) or float(o.get("die_t", -1)) >= 0.0 or int(o.get("owner", -1)) != 0:
			continue
		if not bool(o.get("is_building", false)) and _dep_harvest_orders._yield_of(int(o.get("unit", -1))) == "": continue
		if float(o.get("hp", 0.0)) <= 0.0: continue
		if not _visibility.is_visible(Vector2(o.ax, o.ay)): continue
		var c := Vector2(float(o.ax), float(o.ay) - float(o.h) * 0.5)
		if absf(pos.x - c.x) > float(o.w) * 0.5 + 8.0 or absf(pos.y - c.y) > float(o.h) * 0.5 + 8.0: continue
		var d := pos.distance_to(c)
		if d < bd: bd = d; best = o
	return best

func _own_object_at(pos: Vector2) -> Dictionary:
	var u := _player_at(pos)
	if not u.is_empty():
		return u
	for o in battle.units:
		if not bool(o.get("alive", false)) or bool(o.is_building) == false or int(o.get("owner", -1)) != battle.player_owner:
			continue
		var cx := float(o.ax)
		var cy := float(o.ay) - float(o.h) * 0.5
		if absf(pos.x - cx) <= float(o.w) * 0.5 + 6.0 and absf(pos.y - cy) <= float(o.h) * 0.5 + 6.0:
			return o
	return {}

func _building_hit(u: Dictionary, pos: Vector2) -> bool:
	return Rect2(Vector2(float(u.ax)-float(u.w)*0.5, float(u.ay)-float(u.h)), Vector2(float(u.w),float(u.h))).grow(4).has_point(pos)

func _attack_target_at(pos: Vector2) -> Dictionary:
	var enemy := _enemy_at(pos)
	if not enemy.is_empty(): return enemy
	# 民房仍可搬运金币；显式攻击允许摧毁它，不把它伪装为敌军。
	return _neutral_object_at(pos)

func _enemy_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 44.0
	for u in battle.units:
		if not u.alive or u.owner == battle.player_owner or u.owner == 0 or u.die_t >= 0.0 or u.get("attached", false) or int(u.get("site_inside_uid", -1)) >= 0:
			continue
		if not _visibility.is_visible(Vector2(u.ax, u.ay)): continue
		var d := pos.distance_to(Vector2(u.ax, u.ay - u.h * 0.5))
		if (bool(u.is_building) and _building_hit(u,pos)) or (not bool(u.is_building) and d < bd):
			bd = d
			best = u
	return best

func _player_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 40.0
	for u in battle.units:
		if not u.alive or u.owner != battle.player_owner or u.die_t >= 0.0:
			continue
		if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0:
			continue                    # 装载中的单位不在图上，不可点选/作为目标
		var d := pos.distance_to(Vector2(u.ax, u.ay - u.h * 0.5))
		if (bool(u.is_building) and _building_hit(u,pos)) or (not bool(u.is_building) and d < bd):
			bd = d
			best = u
	return best

func _select_click(pos: Vector2, add: bool) -> void:
	var u := _player_at(pos)
	if u.is_empty():
		u = _neutral_object_at(pos)
		if u.is_empty(): u = _enemy_at(pos)
		# 敌军只接受攻击目标判定；建筑允许查看生命/存量。
		if not u.is_empty() and not bool(u.get("is_building",false)): u = {}
	if not u.is_empty() and int(u.owner) != battle.player_owner:
		battle.selected.clear()
	elif add:
		battle.selected = battle.selected.filter(func(item): return int(item.owner)==battle.player_owner)
	if not add:
		battle.selected.clear()
	if not u.is_empty() and not (u in battle.selected):
		battle.selected.append(u)
	if _effects != null:
		if not u.is_empty(): _effects.sound("play_select", [[u]])
		elif not battle.selected.is_empty(): _effects.sound("play_select", [battle.selected])

func _select_box(rect: Rect2, add: bool) -> void:
	if not add:
		battle.selected.clear()
	for u in battle.units:
		if not u.alive or u.owner != battle.player_owner or u.is_building:
			continue
		if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0:
			continue                    # 装载中的单位不参与框选
		if rect.has_point(Vector2(u.ax, u.ay - 8)):
			if not (u in battle.selected):
				battle.selected.append(u)
	if not battle.selected.is_empty() and _effects != null:
		_effects.sound("play_select", [battle.selected])

func _hover_unit(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 36.0
	for u in battle.units:
		if not u.alive or int(u.get("site_inside_uid", -1)) >= 0 or (int(u.owner) != battle.player_owner and not _visibility.is_visible(Vector2(u.ax, u.ay))):
			continue
		var d := pos.distance_to(Vector2(u.ax, u.ay - u.h * 0.5))
		if (bool(u.is_building) and _building_hit(u,pos)) or (not bool(u.is_building) and d < bd):
			bd = d
			best = u
	return best

func bind_dependencies(world: Object) -> void:
	_dep_harvest_orders = world.harvest_orders
	_effects = world.effects
	_visibility = world.visibility
