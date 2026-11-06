extends SceneTree
## Four reported regressions: restored gate registration, visible unit stature,
## neutral house interaction, and researched building/production behavior.
var battle: Node2D
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func gates() -> void:
	var count := 0
	for gate in battle.units:
		if int(gate.unit) not in [16,17]: continue
		var expected := 25.0 if int(gate.B)<200 else -19.0
		assert(is_equal_approx(battle.view.unit_nodes(gate).gate_module.foundation_drop,expected),"restored gate must use its actual map cell before attaching its skin")
		assert(Vector2i(gate.A,gate.B)==battle.nav.cell_of_px(gate.ax,gate.ay))
		count+=1
	assert(count==4)

func run() -> void:
	root.get_node("Game").current_map="chibil1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true;battle.ai=null
	var game:=root.get_node("Game")
	gates()
	assert(game.save_game(battle.units,battle.commands._resources(),battle.commands._save_extra()))
	var snapshot: Dictionary=game.load_save()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-save="):
			var file:=FileAccess.open(arg.substr(14),FileAccess.READ)
			assert(file!=null);snapshot=JSON.parse_string(file.get_as_text())
	assert(battle.saver.apply_snapshot(snapshot),"existing save must load with the building registry overlay")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	for size in [Vector2i(640,480),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;await process_frame
		gates()
	var occluders:int=0
	for terrain in battle.view.get_children():
		if terrain.has_method("_setup_gate_apertures"):
			for face in terrain.get_children():
				if face.has_meta("gate_occluder"):
					assert(not face.z_as_relative and face.texture!=null and face.material==terrain.gate_material)
					occluders+=1
	assert(occluders>100,"gate wall must cover units behind the wall without replacing wall art")
	print("GATE OCCLUSION PASS shared baked pixels / absolute depth / aperture preserved / save-load and window resize")
	print("RESTORED GATE PASS four directions / actual save / 640-1280-1920")
	# The same cavalry facing used to display 39px, then 17px and 14px.
	# Measure actual rendered Sprite2D transforms across turn AND walk clips.
	for uid in [30,32,36,45]:
		var parent:=Sprite2D.new();battle.add_child(parent)
		var meta: Dictionary=battle.map_data.units[str(uid)]
		var skin: Sprite2D=battle.remaster_art.create_unit_skin(parent,uid,battle.player_owner,Vector2i(meta.w,meta.h))
		var lo:=INF;var hi:=0.0;var foot_lo:=INF;var foot_hi:=-INF
		for clip in ["turn","walk"]:
			for direction in meta.clips[clip]:
				for frame in direction:
					battle.remaster_art.update_skin(skin,int(frame),false,-1)
					assert(skin.visible,"living clip references must never blink to a transparent label cell")
					var height:=skin.region_rect.size.y*skin.scale.y
					lo=minf(lo,height);hi=maxf(hi,height)
					foot_lo=minf(foot_lo,skin.position.y+height);foot_hi=maxf(foot_hi,skin.position.y+height)
		assert(hi/lo<1.4,"same unit cannot shrink on turn/walk, type=%d range=%f..%f"%[uid,lo,hi])
		assert(foot_hi-foot_lo<=6.0,"feet remain at the source ground anchor")
		if uid==36:
			battle.remaster_art.update_skin(skin,1,false,-1)
			assert(skin.region_rect.size.x<180,"adjacent HD pose must not be included in the sample")
		parent.free()
	print("UNIT STATURE PASS worker / infantry / cavalry / archer across living facings and walk")
	# Visible neutral house: left inspection, explicit attack target, real damage.
	battle.visibility.current.fill(1);battle.visibility.explored.fill(1)
	var house: Dictionary=battle.units.filter(func(u):return int(u.unit) in [24,25] and u.alive and u.die_t<0)[0]
	var point:=Vector2(house.ax,house.ay-house.h*0.5)
	battle.commands._select_click(point,false)
	assert(battle.selected.size()==1 and battle.selected[0]==house)
	battle.view.update_panel()
	assert(battle.view.cmd_capsules.is_empty(),"neutral house inspection never exposes player production commands")
	assert(battle.commands._attack_target_at(point)==house)
	var edge: Vector2=battle.commands._edge_point(house,Vector2(house.ax-150,house.ay+30),battle.DEPOSIT_EDGE_PX)
	assert(battle.commands._spawn_unit(36,battle.player_owner,edge.x,edge.y,true))
	var fighter: Dictionary=battle.units.back()
	battle.selected=[fighter];battle.commands._cmd_begin("attack");battle.commands._resolve_pending(point)
	assert(fighter.target==house and fighter.state=="attack")
	var hp: float=house.hp
	for tick in range(900):
		battle.commands._step_unit(fighter,battle.SIM_DT)
		if house.hp<hp:break
	assert(house.hp<hp,"issuing the attack must actually damage the house")
	print("HOUSE INTERACTION PASS neutral selection / read-only HUD / explicit attack / damage")
	# Building fees and source-confirmed menu dependencies, independent of HQ.
	assert(battle.commands.ai_unit_cost(0)=={"gold":30.0,"wood":500.0,"food":1000.0,"stone":500.0})
	assert(battle.commands.ai_unit_cost(30)=={"gold":400.0,"wood":50.0,"food":50.0,"stone":0.0})
	assert(battle.commands.tech_rows_for_building(4).has(3) and battle.commands.tech_rows_for_building(14).is_empty())
	for row in [13,16]:assert(battle.commands.tech_cost(row).stone in [1000.0,5000.0] and battle.commands.tech_cost(row).food==0)
	for row in [14,17]:assert(battle.commands.tech_cost(row).food in [1000.0,5000.0] and battle.commands.tech_cost(row).stone==0)
	var rules=load("res://simulation/systems/building_rules.gd")
	var frames:=[]
	for hp_fraction in [0.0,0.34,0.67,1.0]:frames.append(rules.construction_frame(hp_fraction*2400,2400,battle.map_data.units["0"],10))
	assert(frames==[9,8,1,0],"HQ uses construction stages, not a linear damage-frame sweep")
	for tier in [0,1,2,3]:
		battle.player_tech.level=tier
		var infantry: Array=battle.commands.train_types_for(12)
		assert(infantry.size()==tier+1 and infantry.back().unit==[32,38,41,43][tier])
		battle.scenario_sides[0].init[0]=(tier+1)%3
		assert(battle.commands.train_types_for(12)==infantry,"scenario init[0] must not override the building's production tier")
	assert(battle.commands.train_types_for(8)[0].unit==34)
	assert(battle.commands.train_types_for(20).map(func(entry):return entry.unit)==[46,47,48,49])
	assert(not battle.commands._dock_can_launch(Vector2(400,2200)),"inland waterless ground is not a dock site")
	print("BUILDING RESEARCH PASS costs / bow / sales / construction stages / HQ tiers / catapult / four ships / shoreline")
	battle.free()
	# A real coastal map already has all production buildings, including a dock.
	# Complete the newly exposed orders, rather than only checking menu labels.
	game.current_map="chibic13"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true;battle.ai=null
	battle.player_tech.level=3
	battle.gold=500000;battle.wood=500000;battle.food=500000;battle.stone=500000
	for pair in [[9,34],[7,40],[13,41],[13,43],[15,42],[15,44],[20,46],[20,47],[20,48],[20,49]]:
		var building: Dictionary=battle.units.filter(func(u):return int(u.unit)==int(pair[0]) and int(u.owner)==battle.player_owner)[0]
		var before:int=battle.units.size()
		assert(battle.commands._queue_train(battle.player_owner,building,int(pair[1])))
		var ticks:=int(battle.map_data.units[str(pair[1])].hp)
		for tick in range(ticks):battle.commands._process_trainings(battle.SIM_DT)
		assert(battle.trainings.is_empty() and battle.units.size()==before+1,"newly admitted unit must finish and leave its building: %d"%int(pair[1]))
		var unit: Dictionary=battle.units.back()
		assert(int(unit.unit)==int(pair[1]) and unit.officer.is_empty())
		if int(pair[0])==20:
			assert(battle.commands._nav_layer(unit)==1 and battle.nav.is_water(Vector2i(unit.A,unit.B)),"ships must actually launch on navigable water")
	print("RESEARCHED PRODUCTION PASS catapult / 500 cavalry / 500-1000 infantry+archer / four ship types launch on water")
	battle.free();done=true;quit()
