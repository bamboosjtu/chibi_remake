extends RefCounted
## Legacy defaults come from immutable map/rule definitions, never a live army.
static func create(live: Node2D) -> RefCounted:
	var fresh=preload("res://simulation/battle_state.gd").new()
	fresh.map_id=live.map_id;fresh.map_data=live.world.definition.duplicate(true)
	var scenario: Dictionary=fresh.map_data.get("scenario",{})
	fresh.scenario_sides=scenario.get("sides",[]).duplicate(true)
	fresh.scenario_mission=int(scenario.get("missionId",-1));fresh.scenario_avi=str(scenario.get("avi",""))
	fresh.scenario_source="battle.exp";fresh.officer_policy="battle.exp"
	if not fresh.scenario_sides.is_empty():
		fresh.player_owner=int(fresh.scenario_sides[0].owner)
		var resources: Array=fresh.scenario_sides[0].get("resources",[0,0,0,0])
		fresh.gold=resources[0];fresh.food=resources[1];fresh.wood=resources[2];fresh.stone=resources[3]
	fresh._officer_pool=preload("res://simulation/definitions/opening_officers.gd").pool(fresh.scenario_sides)
	fresh.terrain_base=fresh.map_data.get("terrainWalkable",fresh.map_data.walkable).duplicate()
	var candidate=preload("res://app/saves/candidate_world.gd").new()
	if not candidate.prepare(fresh,fresh.map_data): candidate.dispose();return null
	var state=candidate.state
	for i in range(state.map_data.objects.size()):
		var unit: Dictionary=candidate._modules.entity_factory._make_unit(state.map_data.objects[i],true)
		unit.map_index=i;state.units.append(unit)
	candidate.commands.world._rebuild_unit_index();state.nav.rebuild_buildings(state.units)
	candidate.commands.world._update_gates();candidate.commands.economy._build_decor_targets()
	candidate.commands.orders._resolve_navigation_overlaps()
	state._officer_initial_state=candidate.commands.military._officer_pool_state()
	form_officers(candidate)
	state.visibility.update(state.units,state.player_owner)
	state.ai=preload("res://simulation/systems/ai.gd").new(candidate.world)
	return candidate

static func form_officers(candidate: RefCounted) -> void:
	var state=candidate.state;var formed := {};var counts := {}
	var soldiers: Array=[]
	for side in state.scenario_sides:
		soldiers.append_array(state.units.filter(func(unit):return int(unit.owner)==int(side.owner) and not unit.is_building))
	for soldier in soldiers:
		if soldier.is_building: continue
		var index:=int(soldier.get("tail_value",0))-1
		var key: String="%d/%d" % [int(soldier.owner),index]
		if index<0 or formed.has(key): continue
		var officer: Dictionary=candidate.commands.military._officer_by_index(index)
		if officer.is_empty(): continue
		if not candidate.commands.world._spawn_unit(int(officer.heroType),int(soldier.owner),float(soldier.ax),float(soldier.ay)): continue
		candidate.commands.world._attach_officer(state.units.back(),officer.duplicate(true));formed[key]=true
	for soldier in soldiers:
		var index:=int(soldier.get("tail_value",0))-1
		var key: String="%d/%d" % [int(soldier.owner),index]
		if formed.has(key) and int(counts.get(key,0))<15:
			soldier.group_officer=index;counts[key]=int(counts.get(key,0))+1
	for unit in state.units:
		if not unit.officer.is_empty(): unit.team_kind=state.command_rules.team_kind(unit)
