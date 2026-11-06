extends RefCounted
const Access = preload("res://simulation/ports/command_rules_access.gd")
var host: Access
var model: Dictionary
func _init(owner: Object) -> void:
	host = owner.simulation_access("command_rules") if owner.has_method("simulation_access") else owner
	model=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/command_variants.json")).three_layer_model

func team_kind(leader: Dictionary) -> String:
	var saved:=str(leader.get("team_kind",""))
	if saved in ["worker","combat"]:return saved
	var index:=int(leader.get("officer",{}).get("index",-1))
	var members: Array=host.units.filter(func(u):return u.alive and u.die_t<0 and int(u.owner)==int(leader.owner) and int(u.get("group_officer",-2))==index)
	return "worker" if not members.is_empty() and members.all(func(u):return host._is_worker_unit(u)) else "combat"

## A complete single team has the commander's panel regardless of selection order.
## Unrelated, unbound and multiple-commander selections retain the mixed rules.
func selected_leader(selected:Array) -> Dictionary:
	var leaders:Array=[]
	for u in selected:
		if not u.get("officer",{}).is_empty() and not leaders.has(u):leaders.append(u)
	if leaders.size()!=1:return {}
	var leader:Dictionary=leaders[0]
	var index:int=int(leader.officer.index)
	return leader if selected.all(func(u):return u==leader or (int(u.owner)==int(leader.owner) and int(u.get("group_officer",-1))==index)) else {}

func describe() -> Dictionary:
	var selected: Array=host.selected.filter(func(u):return u.alive and u.die_t<0 and int(u.owner)==host.player_owner and not bool(u.get("attached",false)))
	if selected.is_empty() or selected.any(func(u):return u.is_building):return {"kind":"","ids":[],"disabled":[]}
	var leader:Dictionary=selected_leader(selected)
	var kind: String
	var ids: Array
	if selected.all(func(u):return int(u.unit)==47):
		kind="transport";ids=model.transport.commands.duplicate()
	elif not leader.is_empty():
		kind=team_kind(leader);ids=model.leader[kind].duplicate()
	else:
		var worker_members: bool=selected.all(func(u):return (team_kind(u)=="worker" if not u.get("officer",{}).is_empty() else host._is_worker_unit(u)) and not host._commander_for(u).is_empty())
		var bound: bool=selected.all(func(u):return not host._commander_for(u).is_empty())
		kind="worker_member" if worker_members else ("combat_member" if bound else "ungrouped")
		ids=(model.member.worker if worker_members else (model.member.combat if bound else model.ungrouped.commands)).duplicate()
		if worker_members or selected.any(func(u):return float(u.get("carry",0))>0):ids.append(16146)
	ids=ids.map(func(id):return int(id))
	var disabled:=[]
	if ids.has(16139) and host._selected_construction_workers().is_empty():disabled.append(16139)
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
	for leader in host.selected:
		if not leader.alive or leader.die_t>=0 or int(leader.owner)!=host.player_owner or bool(leader.get("attached",false)):continue
		if not leader.get("officer",{}).is_empty() and model.leader[team_kind(leader)].any(func(command):return int(command)==id):return true
	return false
