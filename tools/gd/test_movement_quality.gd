extends SceneTree
const Locomotion=preload("res://simulation/systems/locomotion.gd")
## Continuous travel, safe shortcuts, render interpolation and distinct group goals.
var done := false
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map="chibil1"
	var battle: Node2D=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	await process_frame;await process_frame
	battle.view.event_view.restore_history()
	var terrain: Node2D
	for child in battle.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):terrain=child
	assert(terrain!=null)
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		if terrain._pending.is_empty() and terrain._wanted.keys().all(func(k):return terrain.active.has(k)):break
		await create_timer(0.01).timeout
	assert(terrain._pending.is_empty() and not terrain.active.is_empty(),"background terrain loading must complete")
	assert(terrain._wanted.keys().all(func(k):return terrain.active.has(k)))
	assert(terrain.loaded_bytes<=terrain.budget)
	var cached: Dictionary=terrain.active.duplicate()
	terrain.update_visible(terrain.last_rect,false)
	assert(terrain._pending.is_empty() and terrain.active==cached,"revisiting resident chunks must not decode/upload again")
	var leader: Dictionary=battle.selected[0]
	var worker: Dictionary=battle.units.filter(func(u):return int(u.owner)==battle.player_owner and int(u.unit)==30)[0]
	assert(battle.commands._spawn_unit(45,battle.player_owner,600,2200,true))
	var archer: Dictionary=battle.units.back()
	var sim: Node2D=load("res://main.gd").new()
	var walk: Array=[];walk.resize(40*80);walk.fill(1)
	sim.map_data={"rows":40,"cols":80,"terrainW":1848,"terrainH":1000,"tileW":44,"walkable":walk,"terrainWalkable":walk,"units":{}}
	sim.nav.setup(sim.map_data)
	var start: Vector2=sim.nav.anchor_of(5,20)
	var finish: Vector2=sim.nav.anchor_of(20,20)
	var route: Array=sim.nav.find_path(start,finish,true,0,2,30)
	assert(route.size()<=4,"open-ground movement should not follow a grid staircase")
	for actor in [leader,worker,archer]:
		actor.ax=start.x;actor.ay=start.y;actor.A=5;actor.B=20
		actor.path=[start,start+Vector2(1,0),start+Vector2(2,0),start+Vector2(110,0)]
		actor.pi=0;actor.state="move";actor.haste_t=0;actor.slow_t=0
		sim.units=[actor];sim.commands._rebuild_unit_index()
		sim.commands._follow(actor,0.1)
		assert(is_equal_approx(float(actor.ax)-start.x,11.0),"short waypoints must not discard the tick's travel distance")
		assert(is_equal_approx(float(actor.ay),start.y))
	# A shortcut must respect the temporary forbidden crop cells too.
	var avoid: Array=[]
	for x in range(10,14):
		for y in range(16,25):avoid.append(Vector2i(x,y))
	route=sim.nav.find_path_avoiding(start,finish,true,avoid,0,2,30)
	assert(not route.is_empty())
	var previous:=start
	for raw in route:
		var point: Vector2=raw
		var samples:=maxi(1,ceili(previous.distance_to(point)/2))
		for i in range(samples+1):
			var p:=previous.lerp(point,float(i)/samples)
			assert(sim.nav.cell_of_px(p.x,p.y) not in avoid,"smoothing cannot cut through the field")
		previous=point
	# Reconstruct six display frames between two 10Hz simulation ticks.
	battle.units=[worker]
	worker.ax=start.x;worker.ay=start.y
	battle.view.capture_motion();worker.ax+=11
	var positions:=[]
	for fraction in [0.0,0.2,0.4,0.6,0.8,1.0]:
		battle.view.interpolate_motion(fraction)
		positions.append(battle.view.unit_nodes(worker).spr.position.x+float(worker.w)*0.5)
		assert(worker.ax==start.x+11,"render smoothing must never mutate simulation position")
		assert(is_equal_approx(battle.view.unit_nodes(worker).diamond.position.x,positions.back()))
	for i in range(1,positions.size()):assert(is_equal_approx(positions[i]-positions[i-1],2.2))
	archer.moved=true;archer.anim=0.15;archer.state="move";archer.dir=0
	Locomotion.ensure(archer);archer.walk_tick=4;archer.move_facing=0;archer.move_turning=false
	battle.cam.position=Vector2(archer.ax,archer.ay);battle.cam.force_update_scroll()
	battle.commands._update_visual(archer)
	assert(battle.view.unit_nodes(archer).frame==battle.commands._clip_frame(archer,"turn",2,2),"walking advances once per two updates, independently of attack rate")
	var frame: int=battle.view.unit_nodes(archer).frame
	battle.cam.position=Vector2(1800,900);archer.anim=0.25;battle.commands._update_visual(archer)
	assert(not battle.view.unit_nodes(archer).spr.visible and battle.view.unit_nodes(archer).frame==frame,"offscreen units must not stream animation frames")
	# Check all 26 original type/direction lengths, including 8/12 and 9/18 rows.
	var reference_path:String=get_script().resource_path.get_base_dir().path_join("../../research/movements/data/movement.json").simplify_path()
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var active_types:=0
	for row in reference.units:
		# Reserved civilians/ladders/flagship have no current runtime definition.
		if not battle.map_data.units.has(str(int(row.id))):continue
		active_types+=1
		var definition:Dictionary=battle.map_data.units[str(int(row.id))]
		for direction in range(8):
			assert(definition.clips.walk[direction].size()==int(row.walkFramesByDir[direction]))
			var sample:=archer.duplicate();sample.unit=int(row.id);sample.clips=definition.clips
			sample.dir=direction;sample.move_facing=direction;sample.move_turning=false
			var frames_seen:Dictionary={}
			var expected_frames:Dictionary={}
			for value in definition.clips.turn[(direction+2)%8]:expected_frames[value]=true
			for tick in range(definition.clips.turn[(direction+2)%8].size()*2):
				sample.walk_tick=tick;var pose:Dictionary=battle.view.mobile_pose(sample)
				assert(int(pose.step)==tick/2)
				assert(pose.clip=="turn" and int(pose.direction)==(direction+2)%8)
				assert(battle.commands._clip_frame(sample,str(pose.clip),int(pose.direction),int(pose.step))==int(definition.clips.turn[(direction+2)%8][tick/2]))
				frames_seen[battle.commands._clip_frame(sample,str(pose.clip),int(pose.direction),int(pose.step))]=true
			assert(frames_seen.size()==expected_frames.size())
	assert(active_types>=21)
	var legacy:Dictionary={"dir":5,"move_facing":0,"walk_tick":99,"move_started":true,"is_building":false}
	Locomotion.restore({},legacy)
	assert(legacy.move_facing==5 and legacy.walk_tick==0 and not legacy.move_started)
	# A 180-degree corner visits adjacent sectors using turn poses, without resetting gait.
	var turning:Dictionary=archer.duplicate();turning.move_facing=0;turning.dir=4
	turning.walk_tick=120;turning.turn_tick=0;turning.move_started=true;turning.move_turning=false
	var facings:=[0]
	for tick in range(8):
		Locomotion.step(turning)
		var old_facing:int=facings.back();facings.append(int(turning.move_facing))
		assert((int(turning.move_facing)-old_facing+8)%8 in [0,1])
		assert(battle.view.mobile_pose(turning).clip=="turn")
	assert(facings.back()==4 and turning.walk_tick==128)
	Locomotion.step(turning);assert(battle.view.mobile_pose(turning).clip=="turn" and turning.walk_tick==129)
	# Fractional render frames use the same interpolated phase as the feet.
	worker.state="move";worker.moved=true;worker.carry=0;worker.dir=0
	Locomotion.ensure(worker);worker.move_facing=0;worker.move_turning=false;worker.walk_tick=1
	battle.view.capture_motion();worker.walk_tick=2;worker.ax+=3.0
	battle.cam.position=Vector2(worker.ax,worker.ay);battle.cam.force_update_scroll();battle.commands._update_visual(worker)
	battle.view.interpolate_motion(0.5);assert(battle.view.unit_nodes(worker).frame==battle.commands._clip_frame(worker,"turn",2,0))
	battle.view.interpolate_motion(1.0);assert(battle.view.unit_nodes(worker).frame==battle.commands._clip_frame(worker,"turn",2,1))
	assert(worker.walk_tick==2,"rendering must not advance the gait clock")
	sim.free();battle.free()
	# A real five-member team receives five separate, body-sized destinations.
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	await process_frame;await process_frame
	battle.commands._move_selected_to(battle.nav.anchor_of(20,190))
	var endpoints:=[]
	for actor in battle.commands._command_units():
		assert(actor.state=="move" and not actor.path.is_empty())
		var goal: Vector2=actor.path.back()
		var cell: Vector2i=battle.nav.cell_of_px(goal.x,goal.y)
		assert(cell not in endpoints,"team members must not compete for one endpoint")
		endpoints.append(cell)
	assert(endpoints.size()==5)
	# Persist a corner midway; after load the visual state and next update agree.
	var actor:Dictionary=battle.commands._command_units()[0]
	Locomotion.ensure(actor);actor.move_facing=2;actor.dir=5;actor.walk_tick=37;actor.turn_tick=3;actor.move_turning=true;actor.move_started=true
	assert(battle.commands._save_game())
	var snapshot:Dictionary=root.get_node("Game").load_save()
	var copied:=actor.duplicate(true);Locomotion.step(copied)
	assert(battle.saver.apply_snapshot(snapshot))
	actor=battle.units.filter(func(u):return int(u.uid)==int(copied.uid))[0]
	assert(actor.move_facing==2 and actor.walk_tick==37 and actor.turn_tick==3)
	Locomotion.step(actor)
	for field in Locomotion.FIELDS:assert(actor[field]==copied[field])
	var invalid:Dictionary=snapshot.duplicate(true);invalid.units[0].simulation.move_facing=9
	assert(not battle.saver.apply_snapshot(invalid))
	print("MOVEMENT QUALITY PASS background terrain and reuse / distance budget / safe shortcuts / 10Hz-to-display interpolation / walking cadence / distinct team goals")
	print("MOVEMENT RESEARCH PASS ",active_types," registered types x8 directions / two-update gait / adjacent turn sectors / render phase / save continuity / invalid snapshot rejected")
	battle.free();done=true;quit()
