extends SceneTree
var b:Node2D
var game:Node
var template:Dictionary
var officer:Dictionary
var done:=false
func _initialize() -> void:
	create_timer(100).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func fixture() -> void:
	if b!=null:b.free()
	game.current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	if template.is_empty():template=b.map_data.units.duplicate(true);officer=b.selected[0].officer.duplicate(true)
	while not b.units.is_empty():b.commands.world._free_unit_at(b.units.size()-1)
	var land:Array=[];var water:Array=[]
	for a in range(60):
		for row in range(120):land.append(1 if a>=30 else 0);water.append(1 if a<30 else 0)
	b.map_data={"rows":60,"cols":120,"tileW":44,"terrainW":2684,"terrainH":2684,"walkable":land,"terrainWalkable":land.duplicate(),"waterWalkable":water,"units":template.duplicate(true),"objects":[],"decor":[],"navigation":{}}
	b.terrain_base=land.duplicate();b.nav.setup(b.map_data);b.visibility.setup(Vector2(2684,2684))
	b.decor_targets.clear();b.decor_cells.clear();b.trainings.clear();b.selected=[]
	b.gold=10000;b.wood=10000;b.food=10000;b.stone=10000
func spawn(kind:int,cell:Vector2i,owner:=2) -> Dictionary:
	var point:Vector2=b.nav.anchor_of(cell.x,cell.y)
	assert(b.commands.world._spawn_unit(kind,owner,point.x,point.y,true))
	return b.units.back()
func find(uid:int) -> Dictionary:
	return b.units.filter(func(u):return int(u.uid)==uid)[0]
func hero(cell:Vector2i,owner:=2,index:=42) -> Dictionary:
	var u:=spawn(29,cell,owner);var data:=officer.duplicate(true);data.index=index;data.level=9
	b.commands.world._attach_officer(u,data);u.mou=1000;u.vision=30;u.hold=true;return u
func at(u:Dictionary) -> Vector2:return Vector2(u.ax,u.ay-float(u.h)*0.5)
func cast(caster:Dictionary,index:int,target:Dictionary) -> void:
	b.selected=[caster];b.visibility.update(b.units,b.player_owner)
	b.commands.military._jimou_begin(index);assert(b.jimou_pending==index)
	b.commands.military._jimou_cast_at(at(target))
func snap() -> Dictionary:
	b.world.set_definition(b.map_data)
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()));return game.load_save()
func run() -> void:
	game=root.get_node("Game");fixture()
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("../../research/units/data/units.json").simplify_path()))
	assert(reference.units.size()==26)
	for row in reference.units:
		var meta:Dictionary=b.map_data.units[str(int(row.id))]
		for pair in [["hp","hp"],["attack","attackA"],["attackB","attackB"],["defence","defenceA"],["defenceB","defenceB"],["range","range"],["vision","vision"],["f9","speedRaw"],["expGain","killXp"],["moraleGain","morale"]]:assert(meta[pair[0]]==row[pair[1]])
		assert(meta.costs==[row.cost.gold,row.cost.wood,row.cost.food] and meta.costStone==row.cost.iron)
	var producible:Dictionary={}
	for kinds in b.PRODUCE_BY_BUILDING.values():
		for id in kinds:producible[id]=true
	assert(producible.size()==17)
	for id in [27,28,29,31,33,35,50,51,52]:assert(not producible.has(id))
	print("UNIT DATA PASS 26 canonical types /17 production costs / map-only civilians / reserved types remain outside menus")
	var hq:=spawn(0,Vector2i(37,55));var civilian:=spawn(27,Vector2i(41,58))
	assert(civilian.hp==100 and civilian.attack==0 and civilian.atk_range==0 and b.commands.technology._is_worker_unit(civilian))
	b.map_data.decor=[[42,58,2]];b.map_data.walkable[42*120+58]=0;b.map_data.terrainWalkable=b.map_data.walkable.duplicate();b.terrain_base=b.map_data.terrainWalkable.duplicate()
	b.commands.economy._build_decor_targets();b.nav.rebuild_buildings(b.units)
	var grain:Dictionary=b.decor_cells["42_58"];b.food=0;b.selected=[civilian]
	assert(b.commands.economy._order_gather(grain)==1)
	for tick in range(1200):
		b.commands.orders._step_unit(civilian,b.SIM_DT)
		if b.food==200 and civilian.carry==0:break
	assert(b.food==200 and civilian.carry==0 and not grain.alive)
	b.gold=1000;b.wood=1000;b.food=1000;b.stone=1000
	hq.hp=hq.maxhp-16;b.selected=[civilian];assert(b.commands.economy._order_repair(hq)==1)
	for tick in range(400):
		b.commands.orders._step_unit(civilian,b.SIM_DT)
		if hq.hp==hq.maxhp:break
	assert(hq.hp==hq.maxhp and b.gold==984 and b.wood==984 and b.food==984 and b.stone==984)
	var commander:=hero(Vector2i(40,54));civilian.group_officer=int(commander.officer.index);commander.team_kind="worker"
	hq.site=true;hq.hp=0;b.selected=[commander]
	assert(b.commands.military._construction_workers(commander).is_empty() and not b.commands.economy._valid_build_worker(civilian,hq))
	assert(16139 in b.command_rules.describe().disabled)
	var worker:=spawn(30,Vector2i(41,55));worker.group_officer=int(commander.officer.index)
	assert(b.commands.military._construction_workers(commander)==[worker] and b.commands.economy._valid_build_worker(worker,hq))
	b.construction.enter(civilian,hq);assert(civilian.site_inside_uid<0)
	hq.site=false;hq.hp=hq.maxhp;b.gold=399;b.food=1000;b.wood=1000
	assert(not b.commands.economy._queue_train(2,hq,30) and b.gold==399)
	b.gold=400;var before:int=b.units.size();assert(b.commands.economy._queue_train(2,hq,30) and b.gold==0 and b.wood==950 and b.food==950)
	for tick in range(99):b.commands.economy._process_trainings(b.SIM_DT)
	assert(b.units.size()==before)
	b.commands.economy._process_trainings(b.SIM_DT);assert(b.units.size()==before+1)
	print("CIVILIAN RULES PASS real grain harvest-delivery / repair16 / no construction / mixed crew only workers build / worker400-50-50 and100ticks")
	fixture();var ship:=spawn(47,Vector2i(29,40))
	var far:=spawn(30,Vector2i(30,42));assert(b.commands.orders._dist_to_obj(far,ship)<80 and not b.commands.orders._attach_to_ship(far,ship))
	var near:=spawn(30,Vector2i(30,40));var large:=spawn(41,Vector2i(31,38))
	assert(b.transports.adjacent(near,ship) and b.commands.orders._attach_to_ship(near,ship))
	assert(b.transports.adjacent(large,ship) and b.commands.orders._attach_to_ship(large,ship))
	var ship_id:int=ship.uid;var near_id:int=near.uid;var large_id:int=large.uid
	var offshore:Vector2=b.nav.anchor_of(15,40);ship.ax=offshore.x;ship.ay=offshore.y
	assert(b.commands.orders._order_unload(ship,Vector2(-1000,-1000))==1)
	for tick in range(12):b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.carry_n==2 and near.attached and large.attached,"no distant-land teleport")
	var coast:Vector2=b.nav.anchor_of(29,40);ship.ax=coast.x;ship.ay=coast.y
	for tick in range(3):b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.carry_n==2 and ship.unload_t%4==3)
	var stored:=snap();assert(b.saver.apply_snapshot(stored));ship=find(ship_id);near=find(near_id);large=find(large_id)
	b.selected=[ship];b.commands.military._cmd_begin("unload");b.player_commands.pump()
	assert(b.cmd_pending=="" and ship.unload_t%4==3)
	b.commands.orders._step_unit(ship,b.SIM_DT);assert(ship.carry_n==1 and not near.attached and large.attached)
	assert(b.transports.adjacent(near,ship) and not b.nav.is_solid(b.commands.world._unit_cell(near),0))
	for tick in range(4):b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.carry_n==0 and not large.attached and b.transports.adjacent(large,ship))
	print("UNIT TRANSPORT PASS body adjacency /80px gap rejected / large passenger / immediate button / offshore wait /4tick cadence / saved phase")
	fixture();var caster:=hero(Vector2i(40,30));var member:=spawn(30,Vector2i(41,30));member.group_officer=42
	var distant:=spawn(30,Vector2i(52,70));distant.group_officer=42
	var unrelated:=spawn(30,Vector2i(42,30));caster.mou=200
	var morale:float=caster.status_173
	cast(caster,0,member)
	assert(caster.inspired_t==800 and distant.inspired_t==800 and unrelated.inspired_t==0 and caster.status_173==morale and caster.mou==150)
	b.sim_tick=100;b.commands.military._process_officer_recovery();assert(caster.mou==155)
	caster.mou=1000;cast(caster,1,member);assert(member.haste_t==800 and distant.haste_t==800 and unrelated.haste_t==0)
	for i in range(18):var extra:=spawn(30,Vector2i(45+i%8,80+i));extra.group_officer=42
	assert(b.stratagems.target_team(member).size()==15)
	var enemy:=hero(Vector2i(45,30),3,66);var enemy_member:=spawn(32,Vector2i(48,70),3);enemy_member.group_officer=66
	cast(caster,2,enemy);assert(enemy.slow_t==800 and enemy_member.slow_t==800 and enemy.haste_t==0)
	enemy.state="move";enemy.path=[b.nav.anchor_of(46,30)];enemy.pi=0
	cast(caster,4,enemy);var point:=Vector2(enemy.ax,enemy.ay);b.commands.orders._step_unit(enemy,b.SIM_DT)
	assert(enemy.state=="move" and not enemy.path.is_empty() and Vector2(enemy.ax,enemy.ay)!=point and enemy.effect_task==0)
	for tick in range(100):
		b.commands.orders._step_unit(enemy,b.SIM_DT)
		if enemy.effect_task==27:break
	assert(enemy.effect_task==27 and enemy.state=="idle" and enemy.confused_t>0)
	point=Vector2(enemy.ax,enemy.ay);b.commands.orders._step_unit(enemy,b.SIM_DT);assert(Vector2(enemy.ax,enemy.ay)==point)
	# A queued confusion that expires while marching must not freeze the later idle unit.
	enemy.effect_task=0;enemy.effect_tasks=[];enemy.confused_t=0;enemy.state="move";enemy.path=[b.nav.anchor_of(48,30)];enemy.pi=0
	b.stratagems.set_status(enemy,5);enemy.confused_t=1
	b.commands.orders._step_unit(enemy,b.SIM_DT);assert(enemy.confused_t==0 and enemy.effect_task==0)
	for tick in range(100):b.commands.orders._step_unit(enemy,b.SIM_DT)
	assert(enemy.effect_task==0 and enemy.effect_tasks.is_empty())
	fixture();caster=hero(Vector2i(40,30));var trap:=spawn(30,Vector2i(42,32));trap.hold=true
	var victim:=hero(Vector2i(48,34),3,67);victim.hp=200;victim.status_173=70
	var nearer:=hero(Vector2i(43,32),3,68);nearer.status_173=70
	cast(caster,5,trap)
	for tick in range(29):b.commands.orders._step_unit(trap,b.SIM_DT)
	assert(victim.hp==200 and victim.status_173==70 and trap.rolling_ticks==29)
	var trap_id:int=trap.uid;var victim_id:int=victim.uid;var nearer_id:int=nearer.uid
	stored=snap();assert(b.saver.apply_snapshot(stored));trap=find(trap_id);victim=find(victim_id);nearer=find(nearer_id)
	b.commands.orders._step_unit(trap,b.SIM_DT);assert(victim.hp==200 and victim.status_173==20 and nearer.status_173==70 and trap.rolling_t==0)
	for tick in range(35):b.commands.orders._step_unit(trap,b.SIM_DT)
	assert(victim.status_173==20)
	print("UNIT STRATAGEM PASS team15 / distant members / inspiration MOU / confusion queues behind work and expires / rolling first enemy in vision morale50 once / saved29th tick")
	fixture();caster=hero(Vector2i(40,30));member=spawn(32,Vector2i(41,30));member.group_officer=42
	var archer:=spawn(45,Vector2i(42,30));archer.group_officer=42
	var cavalry:=spawn(36,Vector2i(43,30));cavalry.group_officer=42
	cast(caster,6,member)
	assert(b.CombatRules.effective_range(member)==5 and b.CombatRules.effective_range(archer)==7 and not b.CombatRules.ambush(cavalry))
	b.stratagems.set_status(member,4);assert(b.CombatRules.effective_range(member)==5 and b.visibility.effective_vision(member)==10)
	victim=hero(Vector2i(44,30),3,67);victim.defence=9999;victim.defence_b=9999
	assert(b.commands.military._damage(member,victim)==30 and b.commands.military._damage(archer,victim)==30)
	b.commands.military._fire_attack(member,victim);assert(b.projectiles.active.size()==1 and b.projectiles.active[0].kind=="ambush")
	for tick in range(100):b.projectiles.step()
	assert(victim.hp==470)
	b.stratagems.set_status(victim,6);b.visibility.update(b.units,b.player_owner)
	assert(is_same(b.commands.military._nearest_enemy(member,1000),victim),"ambush must remain targetable")
	caster.hp=400;member.hp=50;cast(caster,7,member)
	assert(caster.hp==450 and member.hp==50,"healing only affects the team's commander")
	b.stratagems.set_status(member,2);assert(b.commands.military._spd_mult(member)==2 and member.slow_t==0)
	b.stratagems.set_status(member,3);assert(b.commands.military._spd_mult(member)==0.5 and member.haste_t==0)
	var ship_haste:=spawn(47,Vector2i(25,40));b.stratagems.set_status(ship_haste,2);assert(b.commands.military._spd_mult(ship_haste)==1)
	# Last status update still gets its effect; clearing happens after that action.
	member.haste_t=1;member.slow_t=0;member.state="move";member.path=[b.nav.anchor_of(45,35)];member.pi=0
	point=Vector2(member.ax,member.ay);b.commands.orders._step_unit(member,b.SIM_DT)
	assert(is_equal_approx(Vector2(member.ax,member.ay).distance_to(point),b.SPEED*2*b.SIM_DT) and member.haste_t==0)
	print("UNIT COMBAT PASS ambush32/45 range5/7 fixed30 delayed hit ignores defence / visible / healing commander50 / haste2 slow0.5 mutually exclusive / naval no extra haste / final800th update")
	fixture();caster=hero(Vector2i(40,30));var fire_cell:=Vector2i(42,30)
	var fire_point:Vector2=b.nav.anchor_of(fire_cell.x,fire_cell.y)
	victim=hero(fire_cell,2,67);victim.defence=9999;victim.defence_b=9999;victim.hp=500
	# Fire is a ground command, independent of unit sprite picking.
	b.selected=[caster];b.commands.military._jimou_begin(8);b.commands.military._jimou_cast_at(fire_point)
	assert(b.fire_fields.active.size()==1 and caster.mou==900)
	for tick in range(4):b.fire_fields.step()
	assert(victim.hp==500 and b.fire_fields.active[0].age==4)
	victim_id=int(victim.uid);stored=snap();assert(b.saver.apply_snapshot(stored));victim=find(victim_id)
	b.fire_fields.step();assert(victim.hp==490,"first hit on5th global update, including friendlies")
	var safe_point:Vector2=b.nav.anchor_of(44,30);victim.ax=safe_point.x;victim.ay=safe_point.y
	for tick in range(4):b.fire_fields.step()
	assert(victim.hp==490,"fire must stay on ground rather than following its target")
	victim.ax=fire_point.x;victim.ay=fire_point.y
	for tick in range(91):b.fire_fields.step()
	assert(victim.hp==270 and b.fire_fields.active.is_empty(),"24 total windows; one missed while outside")
	var house:=spawn(22,Vector2i(46,40),0);var another:=spawn(30,Vector2i(46,40))
	var before_hp:float=house.hp;assert(b.fire_fields.ignite(Vector2(house.ax,house.ay)))
	for tick in range(100):b.fire_fields.step()
	assert(house.hp==before_hp-240 and another.hp==100,"first occupant only, buildings included")
	stored=snap()
	for bad_fire in [[{"a":-1,"b":0,"age":0}],[{"a":0,"b":0,"age":100}],[{"a":0,"b":0,"age":0.5}]]:
		var corrupt:=stored.duplicate(true);corrupt.simulation.fireFields=bad_fire
		assert(not b.saver.apply_snapshot(corrupt))
	for bad_queue in [[27,27],[27,28,27],[42],null]:
		var corrupt:=stored.duplicate(true);corrupt.units[0].simulation.effect_tasks=bad_queue
		assert(not b.saver.apply_snapshot(corrupt))
	var legacy:=stored.duplicate(true)
	for record in legacy.units:
		record.simulation.erase("ambush_t");record.simulation.erase("effect_tasks");record.simulation.erase("effect_task")
	legacy.units[0].simulation.hidden_t=100
	assert(b.saver.apply_snapshot(legacy) and b.units[0].ambush_t==100,"legacy stealth flag migrates to visible ambush")
	print("UNIT FIRE PASS one ground cell / first hit5 then9..97 / fixed10 / friendly and buildings / leave-reenter /240max / phase save / malformed states rejected / legacy ambush migration")
	print("UNIT RESEARCH PASS research/units + confirmed research/magics; provisional repair tuning and user encounter combat retained")
	b.free();done=true;quit()
