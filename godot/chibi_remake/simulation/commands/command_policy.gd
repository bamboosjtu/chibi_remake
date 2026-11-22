extends RefCounted
const Roles = preload("res://simulation/definitions/unit_roles.gd")
var _state: RefCounted
var _dep_command_groups: Object
var _dep_technology: Object
var model: Dictionary
func _init(owner: Object) -> void:
	_state = owner.state
	_dep_command_groups = owner.command_groups
	_dep_technology = owner.technology
	model = preload("res://simulation/definitions/rule_catalog.gd").get_catalog("command_variants.json").three_layer_model

func team_kind(leader: Dictionary) -> String:
	var saved:=str(leader.get("team_kind",""))
	if saved in ["worker","combat"]:return saved
	var index:=int(leader.get("officer",{}).get("index",-1))
	var members: Array=_state.units.filter(func(u):return u.alive and u.die_t<0 and int(u.owner)==int(leader.owner) and int(u.get("group_officer",-2))==index)
	return "worker" if not members.is_empty() and members.any(func(u):return _dep_technology._is_harvester_unit(u)) else "combat"

## A complete single team has the commander's panel regardless of selection order.
## Unrelated, unbound and multiple-commander selections retain the mixed rules.
func selected_leader(selected:Array) -> Dictionary:
	var leaders:Array=[]
	for u in selected:
		if not u.get("officer",{}).is_empty() and not leaders.has(u):leaders.append(u)
	if leaders.size()!=1:return {}
	var leader:Dictionary=leaders[0]
	var index:int=int(leader.officer.index)
	return leader if selected.all(func(u):return is_same(u,leader) or (int(u.owner)==int(leader.owner) and int(u.get("group_officer",-1))==index)) else {}

func describe() -> Dictionary:
	var selected: Array=_state.selected.filter(func(u):return u.alive and u.die_t<0 and int(u.owner)==_state.player_owner and not bool(u.get("attached",false)))
	if selected.is_empty() or selected.any(func(u):return u.is_building):return {"kind":"","ids":[],"disabled":[]}
	var leader:Dictionary=selected_leader(selected)
	var kind: String
	var ids: Array
	if selected.all(func(u):return Roles.is_transport(int(u.unit))):
		kind="transport";ids=model.transport.commands.duplicate()
	elif not leader.is_empty():
		kind=team_kind(leader);ids=model.leader[kind].duplicate()
	else:
		var worker_members: bool=selected.all(func(u):return (team_kind(u)=="worker" if not u.get("officer",{}).is_empty() else _dep_technology._is_harvester_unit(u)) and not _dep_command_groups._commander_for(u).is_empty())
		var bound: bool=selected.all(func(u):return not _dep_command_groups._commander_for(u).is_empty())
		kind="worker_member" if worker_members else ("combat_member" if bound else "ungrouped")
		ids=(model.member.worker if worker_members else (model.member.combat if bound else model.ungrouped.commands)).duplicate()
		if worker_members or selected.any(func(u):return float(u.get("carry",0))>0):ids.append(16146)
	ids=ids.map(func(id):return int(id))
	var disabled:=[]
	if ids.has(16139) and _dep_command_groups._selected_construction_workers().is_empty():disabled.append(16139)
	if kind=="transport" and not selected.any(func(u):return int(u.get("carry_n",0))>0):disabled.append(16143)
	# Research leaves secondary member checks open. Preserve existing valid group rules.
	if kind in ["combat_member","ungrouped"] and not selected.any(func(u):return u.get("officer",{}).is_empty() and int(u.get("group_officer",-1))<0):disabled.append_array([16144,16145])
	return {"kind":kind,"ids":ids,"disabled":disabled}

func allows(id: int) -> bool:
	var state:=describe()
	return id in state.ids and id not in state.disabled

## Context orders can be issued by a selected commander even when the member
## panel is shown for the complete control group. Members alone keep their limits.
func allows_context(id: int) -> bool:
	if allows(id):return true
	for leader in _state.selected:
		if not leader.alive or leader.die_t>=0 or int(leader.owner)!=_state.player_owner or bool(leader.get("attached",false)):continue
		if not leader.get("officer",{}).is_empty() and model.leader[team_kind(leader)].any(func(command):return int(command)==id):return true
	return false
