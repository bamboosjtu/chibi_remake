extends SceneTree
## Exhaust an entire dense field, including its center; verify navigation and
## old-save reconstruction, team attacks, and reachable first-mission enemies.
var template_meta: Dictionary
var done:=false
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()

func fixture(phase: int) -> Node2D:
	var sim:Node2D=load("res://main.gd").new()
	sim.saver=load("res://app/save_service.gd").new(sim)
	sim.map_id="chibil1";sim.player_owner=2;sim.food=0;sim.wood=0
	var walk:Array=[];walk.resize(40*60);walk.fill(1)
	var decor:Array=[]
	for a in range(12,17):
		for b in range(20,25):walk[a*60+b]=0;decor.append([a,b,phase])
	sim.map_data={"rows":40,"cols":60,"terrainW":1848,"terrainH":700,"tileW":44,"walkable":walk,"terrainWalkable":walk.duplicate(),"decor":decor,"units":template_meta.duplicate(true)}
	sim.terrain_base=walk.duplicate()
	sim.nav.setup(sim.map_data);sim.visibility.setup(Vector2(1848,700))
	for item in [[0,6,22],[30,8,19],[30,8,25]]:
		var p:Vector2=sim.nav.anchor_of(item[1],item[2])
		assert(sim.commands.world._spawn_unit(item[0],2,p.x,p.y,true))
	sim.commands.economy._build_decor_targets();sim.nav.rebuild_buildings(sim.units)
	sim.selected=sim.units.filter(func(u):return int(u.unit)==30)
	return sim

func entire_field(phase: int) -> void:
	var sim:=fixture(phase)
	var center:Dictionary=sim.decor_cells["14_22"]
	assert(sim.nav.is_solid(Vector2i(14,22)),"live center blocks ordinary movement")
	assert(sim.commands.economy._order_gather(center)==2,"an interior click must assign real reachable boundary resources")
	var workers:Array=sim.selected.duplicate()
	var reloaded:=false
	for tick in range(20000):
		sim.sim_tick+=1
		for worker in workers:
			sim.commands.orders._step_unit(worker,sim.SIM_DT)
			var cell:Vector2i=sim.commands.world._unit_cell(worker)
			var source:Dictionary=sim.decor_cells.get("%d_%d"%[cell.x,cell.y],{})
			assert(source.is_empty() or not source.alive,"no walking through unharvested resource cells")
		if not reloaded and sim.decor_targets.filter(func(o):return not o.alive).size()>=10:
			var game:=root.get_node("Game")
			assert(game.save_game(sim.units,sim.commands.world._resources(),sim.commands.session._save_extra()))
			assert(sim.saver.apply_snapshot(game.load_save()))
			workers=sim.units.filter(func(u):return int(u.unit)==30)
			reloaded=true
		if sim.decor_targets.all(func(o):return not o.alive) and workers.all(func(w):return float(w.carry)==0):break
	assert(reloaded and sim.decor_targets.all(func(o):return not o.alive),"must harvest the center, not stop after the outer rows")
	assert(is_equal_approx(float(sim.food if phase==2 else sim.wood),5000),"all 25 cells must actually reach the depot")
	assert(not sim.nav.is_solid(Vector2i(14,22)),"harvested center becomes usable floor")
	assert(not sim.commands.orders._path_to(workers[0],sim.nav.anchor_of(14,22),true).is_empty())
	sim.nav.rebuild_buildings(sim.units)
	assert(not sim.nav.is_solid(Vector2i(14,22)),"building-grid rebuild must not seal harvested ground again")
	print("RESOURCE FRONTIER PASS phase=",phase," 25 cells / center / 5000 delivered / no live-cell traversal / mid-field save / rebuild")
	sim.free()

func run() -> void:
	root.get_node("Game").current_map="chibil1"
	var battle:Node2D=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	template_meta=battle.map_data.units.duplicate(true)
	entire_field(2);entire_field(0)
	var nav=load("res://simulation/navigation/nav.gd").new()
	var land:Array=[];land.resize(64);land.fill(1)
	var water:Array=[];water.resize(64);water.fill(0);water[27]=1;land[27]=0
	nav.setup({"rows":8,"cols":8,"walkable":land,"terrainWalkable":land,"waterWalkable":water})
	var shore:Vector2=nav.anchor_of(3,3)
	nav.set_resources([{"ax":shore.x,"ay":shore.y,"phase":0,"alive":true}])
	nav.clear_resource(Vector2i(3,3));nav.rebuild_buildings([])
	assert(nav.is_solid(Vector2i(3,3)) and nav.is_water(Vector2i(3,3)),"clearing a shoreline tree cannot build a land bridge over water")
	await process_frame;await process_frame
	battle.view.minimap.queue_redraw()
	await process_frame
	assert(battle.view.minimap.map_texture.get_width()==384 and battle.view.minimap.catalog.size()==34)
	assert(battle.view.minimap.fog_material.get_shader_parameter("fog_mask")==battle.view.fog_sprite.texture,"minimap must consume explored and current vision, not just unit dots")
	print("MINIMAP EXPLORATION PASS 34 HD terrain maps / shared persistent exploration mask")
	# The first mission's soldiers are present, on land, and reachable beyond
	# the north-east road. Discovery must not rely on revealing the whole map.
	var enemies:Array=battle.units.filter(func(u):return int(u.owner)==3 and u.alive and u.die_t<0)
	assert(enemies.size()==21)
	var scout:Dictionary=battle.selected[0]
	var routes:=0
	for enemy in enemies:
		var path:Array=battle.commands.orders._edge_interaction_path(scout,enemy)
		if not path.is_empty():routes+=1
	assert(routes>0,"enemy camp must be reachable from the player's starting area")
	print("FIRST MISSION ENEMIES PASS 21 alive / north-east camp / reachable from player start")
	# Select the worker commander, then issue one explicit attack on a house.
	var house:Dictionary=battle.units.filter(func(u):return int(u.unit) in [24,25] and u.alive)[0]
	var team:Array=battle.commands.military._command_units()
	assert(team.size()==5)
	assert(battle.commands.orders._attack_selected(house)==team.size(),"workers must receive the same explicit attack order as their commander")
	for member in team:assert(member.target==house and member.state=="attack")
	var worker:Dictionary=team.filter(func(u):return int(u.unit)==30)[0]
	var edge:Vector2=battle.commands.orders._edge_point(house,Vector2(house.ax-150,house.ay+30),battle.DEPOSIT_EDGE_PX)
	worker.ax=edge.x;worker.ay=edge.y;worker.A=battle.nav.cell_of_px(edge.x,edge.y).x;worker.B=battle.nav.cell_of_px(edge.x,edge.y).y
	var hp:float=house.hp
	for tick in range(300):
		battle.commands.orders._step_unit(worker,battle.SIM_DT)
		if float(house.hp)<hp:break
	assert(float(house.hp)<hp,"a worker must really damage the neutral house")
	print("WORKER TEAM ATTACK PASS commander + four workers / same target / real worker damage")
	battle.free();done=true;quit()
