extends SceneTree
var done := false
var battle
func _initialize() -> void:
	create_timer(600).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func open_map(id: String) -> void:
	if battle!=null: battle.scene.ready_to_save=false;battle.free()
	root.get_node("Game").current_map=id
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	for stage in battle.rules.missions.get(str(battle.scenario_mission),{}).get("stages",[]): check_reference(stage.condition)

func check_reference(condition: Dictionary) -> void:
	if condition.get("kind")=="all":
		for child in condition.conditions:check_reference(child)
	if condition.has("rect"):
		var r: Array=condition.rect
		# Tolerance rectangles may extend past an edge (L6 ends at A=105 on
		# a 105-row map). They need a nonempty intersection, not full containment.
		assert(r.size()==4 and r[0]<=r[1] and r[2]<=r[3] and r[0]<battle.map_data.rows and r[1]>=0 and r[2]<battle.map_data.cols and r[3]>=0,"Objective rectangle has no cells on the actual map")
	for field in ["officer","otherOfficer"]:
		if not condition.has(field):continue
		var side: String=str(condition.get("side","player")) if field=="officer" else str(condition.otherSide)
		assert(battle.units.any(func(unit):return int(unit.get("officer",{}).get("index",-1))+1==int(condition[field]) and ((int(unit.owner)==battle.player_owner) if side=="player" else (int(unit.owner)!=battle.player_owner and int(unit.owner)!=0))),"Objective actor/side missing from actual chapter")
func hero(id: int) -> Dictionary:
	return battle.units.filter(func(unit):return int(unit.get("officer",{}).get("index",-1))+1==id)[0]
func move(unit: Dictionary, cell: Vector2i) -> void:
	var point: Vector2=battle.nav.anchor_of(cell.x,cell.y)
	unit.ax=point.x;unit.ay=point.y;unit.A=cell.x;unit.B=cell.y
	battle.world.battle_simulation._place_unit(unit)
func run() -> void:
	root.size=Vector2i(1920,1080)
	var maps:=DirAccess.get_files_at("res://data");var count:=0
	for file in maps:
		if not str(file).begins_with("chibi") or not str(file).ends_with(".json"):continue
		open_map(str(file).trim_suffix(".json"));battle.world.battle_simulation._sim_step(battle.SIM_DT)
		assert(battle.sim_tick==1 and battle.game_end==0,"Initial battle ended: "+str(battle.map_id))
		count+=1;await process_frame
	assert(count==34)
	print("CAMPAIGN FIRST TICK PASS 34 real maps / no initial victory or defeat")
	for id in ["chibic3","chibic7","chibic14","chibil6","chibil8"]:
		open_map(id)
		var required: int={"chibic14":60,"chibil6":40,"chibil8":34}.get(id,0)
		if required>0:
			battle.world.combat._kill(hero(required))
			assert(battle.units.any(func(unit):return int(unit.owner)==battle.player_owner and unit.alive and unit.die_t<0))
		else:
			for unit in battle.units:
				if int(unit.owner)==battle.player_owner:unit.alive=false;unit.die_t=0
		battle.world.campaign._check_end();assert(battle.game_end==2,id+" real defeat condition")
	print("CAMPAIGN DEFEAT PASS army wipe / required Liu Bei, Zhao Yun and Cao Cao / five real maps")
	for entry in [["chibil6",40,Vector2i(56,135),Vector2i(96,275)],["chibil8",34,Vector2i(10,84),Vector2i(100,300)],["chibic14",60,Vector2i(78,278),Vector2i(12,35)]]:
		open_map(entry[0])
		if entry[0]=="chibil8":
			move(hero(34),entry[3]);battle.world.campaign._check_end();assert(battle.game_end==0 and not battle.task_latches.get("8/b",false))
		move(hero(entry[1]),entry[2]);battle.world.campaign._check_end()
		assert(battle.game_end==0)
		move(hero(entry[1]),entry[3]);battle.world.campaign._check_end();assert(battle.game_end==1,entry[0]+" success")
	l14()
	for entry in [["chibic3",Vector2i(50,60)],["chibic4",Vector2i(63,241)]]:
		open_map(entry[0]);assert(battle.rules.tick()==0 and battle.task_latches.is_empty())
		var unit: Dictionary=battle.units.filter(func(u):return int(u.owner)==battle.player_owner and not u.is_building)[0]
		move(unit,entry[1]);assert(battle.rules.tick()==0)
		assert(battle.task_latches.size()==1);var progress: Dictionary=battle.officer_progress.duplicate()
		assert(battle.rules.tick()==0 and battle.officer_progress==progress)
	open_map("chibic11");assert(battle.rules.tick()==0)
	assert(battle.world.entity_factory._spawn_unit(49,battle.player_owner,3000,2000,true))
	assert(battle.rules.tick()==0 and battle.task_events.size()==1)
	open_map("chibic13")
	for unit in battle.units:
		if int(unit.owner)==2:unit.alive=false;unit.die_t=0
	battle.world.campaign._check_end();assert(battle.game_end==1 and battle.objective_done)
	print("CAMPAIGN OBJECTIVES PASS eight real scripted chapters / positive and negative conditions / once-only stages")
	battle.scene.ready_to_save=false;battle.free();done=true;quit()
func l14() -> void:
	open_map("chibil14");var cao:=hero(60)
	assert(int(cao.owner)==3 and battle.player_owner==2)
	battle.ai._assault[3]=71;battle.ai._assault_maybe(3)
	assert(battle.units.any(func(u):return int(u.owner)==3 and u.state=="attack"),"Actual L14 bypasses development waiting")
	var initial_morale: int=hero(34).status_173
	for id in [34,35,36]:
		var other:=hero(id);assert(int(other.owner)==2)
		move(cao,Vector2i(int(other.A),int(other.B)));battle.world.campaign._check_end()
		assert(battle.task_events.size()==id-33)
	assert(battle.game_end==1 and hero(34).status_173==initial_morale+40)
	battle.world.campaign._check_end();assert(battle.task_events.size()==3)
	open_map("chibil14");move(hero(36),Vector2i(70,200))
	move(hero(60),Vector2i(12,35));battle.world.campaign._check_end()
	assert(battle.game_end==2 and battle.task_latches.get("14/rect",false))
	assert(battle.rules.tick()==2,"Failed scripted exit stays failed")
	print("L14 REAL CHAPTER PASS enemy Cao / player interceptors / three events and morale / escape defeat / AI bypass")
