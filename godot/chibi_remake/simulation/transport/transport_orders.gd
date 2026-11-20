extends Object
const UnitPath = preload("res://simulation/movement/unit_path.gd")
var _transports: RefCounted
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const EffectsRuntime = preload("res://simulation/ports/battle_events.gd")
var _effects: EffectsRuntime
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
## transport orders: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State
var _dep_abilities: Object
var _dep_battle_simulation: Object
var _dep_command_groups: Object
var _dep_spatial_index: Object

func _init(data: State) -> void:
	battle = data

func _cmd_board_at(pos: Vector2) -> void:
	var ship := _own_ship_at(pos)
	if ship.is_empty():
		_effects.feedback("上船：请点自己的运输船（本关没有我方运输船）" if not _has_own_transport() else "上船：请点自己的运输船")
		return
	_order_board(ship)

func _cmd_unload_at(pos: Vector2) -> void:
	var ship := _selected_transport()
	if ship.is_empty():
		_effects.feedback("下船：请先选中一艘运输船")
		return
	_order_unload(ship, pos)

func _own_ship_at(pos: Vector2) -> Dictionary:
	for u in battle.units:
		if not _transports.valid_ship(u):
			continue
		if int(u.get("owner", -1)) != battle.player_owner:
			continue
		var cx := float(u.ax)
		var cy := float(u.ay) - float(u.h) * 0.5
		if absf(pos.x - cx) <= float(u.w) * 0.5 + 6.0 and absf(pos.y - cy) <= float(u.h) * 0.5 + 6.0:
			return u
	return {}

func _selected_transport() -> Dictionary:
	for u in battle.selected:
		if _transports.valid_ship(u) and int(u.owner)==battle.player_owner:
			return u
	return {}

func _has_own_transport() -> bool:
	for u in battle.units:
		if bool(u.get("alive", false)) and int(u.get("unit", -1)) == Roles.transport_id() and int(u.get("owner", -1)) == battle.player_owner:
			return true
	return false

func _order_board(ship: Dictionary, actors = null) -> int:
	if not _transports.valid_ship(ship) or int(ship.owner)!=battle.player_owner or str(ship.state)=="unload":
		_effects.feedback("上船：请选择有效的我方运输船")
		return 0
	_transports.reconcile()
	if int(ship.get("carry_n", 0)) >= Balance.transport_capacity():
		_effects.feedback("运输船已满（%d）" % Balance.transport_capacity())
		return 0
	var n := 0
	for u in _dep_command_groups._command_units(actors):
		if not _transports.valid_unit(u) or bool(u.is_building) or int(u.owner)!=battle.player_owner:
			continue
		if _dep_command_groups._is_naval(u) or bool(u.get("attached", false)):
			continue
		_dep_command_groups._cancel_unit_command(u)
		u["board_target"] = ship
		u["state"] = "board"
		UnitPath.set_points(u, _transports.boarding_path(u,ship) if not _transports.adjacent(u,ship) else [])
		u["pi"] = 0
		n += 1
	if n > 0:
		_effects.feedback("%d 支部队前往上船（载员 %d/%d）" % [n, int(ship.get("carry_n", 0)), Balance.transport_capacity()])
	else:
		_effects.feedback("没有可上船的部队（水军/已装载单位不能上船）")
	return n

func _attach_to_ship(u: Dictionary, ship: Dictionary) -> bool:
	if not _transports.valid_unit(u) or not _transports.valid_ship(ship) or int(u.owner)!=int(ship.owner) or bool(u.is_building) or _dep_command_groups._is_naval(u) or bool(u.get("attached",false)) or str(ship.state)=="unload":return false
	if not _transports.adjacent(u,ship):return false
	_transports.reconcile()
	if int(ship.get("carry_n", 0)) >= Balance.transport_capacity():
		_effects.feedback("运输船已满（%d）" % Balance.transport_capacity())
		return false
	_dep_command_groups._cancel_unit_command(u)
	u["attached"] = true
	u["aboard_uid"] = int(ship.uid)
	u["state"] = "boarded"
	UnitPath.set_points(u, [])
	u["pi"] = 0
	u["target"] = null
	u["board_target"] = null
	u["gather_obj"] = null
	ship["carry_n"] = int(ship.get("carry_n", 0)) + 1
	ship["carry_hp"] = float(ship.get("carry_hp", 0.0)) + float(u.get("hp", 0.0))
	ship["loaded"] = true
	battle.selected.erase(u)
	_dep_spatial_index._index_forget(u)               # R13：装载后不再占陆地格
	_dep_spatial_index._target_forget(u)              # 装载中的单位不可被索敌
	if is_same(battle.jimou_caster, u):
		_dep_abilities._reset_jimou()             # R07：上船后不能继续确认施法
	if _effects != null:
		_effects.visual("set_unit_attached", [u, true])
	_effects.feedback("装载：%s 上船（%d/%d）" % [str(u.get("name", "部队")), int(ship.carry_n), Balance.transport_capacity()])
	return true

func _detach_from_ship(u: Dictionary, ship: Dictionary) -> bool:
	if not _transports.valid_unit(u) or not _transports.valid_ship(ship) or not bool(u.get("attached",false)) or int(u.get("aboard_uid",-1))!=int(ship.uid) or int(u.owner)!=int(ship.owner):return false
	var target_cell: Vector2i=_transports.landing_cell(ship, u)
	if target_cell.x < 0:
		return false
	var point := _nav.anchor_of(target_cell.x, target_cell.y)
	u["attached"] = false
	u["aboard_uid"] = -1
	u["ax"] = point.x
	u["ay"] = point.y
	u["A"] = target_cell.x
	u["B"] = target_cell.y
	u["state"] = "idle"
	UnitPath.set_points(u, [])
	u["pi"] = 0
	if _effects != null:
		_effects.visual("set_unit_attached", [u, false])
	_dep_battle_simulation._place_unit(u)
	ship["carry_n"] = maxi(0, int(ship.get("carry_n", 0)) - 1)
	ship["carry_hp"] = maxf(0.0, float(ship.get("carry_hp", 0.0)) - float(u.get("hp", 0.0)))
	if int(ship.get("carry_n", 0)) <= 0:
		ship["loaded"] = false
	return true

func _unload_selected(actors = null) -> bool:
	var queued := 0
	for ship in battle.selected if actors == null else actors:
		if int(ship.unit)==Roles.transport_id() and _order_unload(ship) > 0:
			queued += 1
	return queued > 0

func _order_unload(ship: Dictionary, _pos:=Vector2.ZERO) -> int:
	if not _transports.valid_ship(ship) or int(ship.owner)!=battle.player_owner:return 0
	var ps: Array = _transports.passengers(ship)
	if ps.is_empty():return 0
	if bool(ship.get("unload_active",false)):return 1
	_dep_command_groups._cancel_unit_command(ship)
	ship.state = "unload"
	ship.unload_active = true
	ship.unload_t = 0
	var landing: Vector2i = _transports.landing_cell(ship, ps[0])
	if landing.x < 0:
		_effects.feedback("下船：等待船只靠岸或岸边空出位置")
		return 1
	_effects.feedback("下船：每 4 拍落位一名，共 %d 名" % ps.size())
	return 1

func _retry_unload(ship: Dictionary) -> int:
	if not _transports.valid_ship(ship):return 0
	var ps: Array = _transports.passengers(ship)
	if ps.is_empty():
		ship.unload_active = false
		if str(ship.get("state", "")) == "unload": ship.state = "idle"
		return 0
	var n := 0
	if _detach_from_ship(ps[0], ship): n = 1
	_transports.reconcile()
	if int(ship.carry_n) == 0:
		ship.unload_active = false
		if str(ship.get("state", "")) == "unload": ship.state = "idle"
	return n

func bind_dependencies(world: Object) -> void:
	_dep_abilities = world.abilities
	_dep_battle_simulation = world.battle_simulation
	_dep_command_groups = world.command_groups
	_dep_spatial_index = world.spatial_index
	_effects = world.effects
	_nav = world.nav
	_transports = world.transports
