extends SceneTree
const AI = preload("res://simulation/systems/ai.gd")
const Targets = preload("res://simulation/systems/ai_targets.gd")
var done := false
var b
var infantry: Dictionary
var hq: Dictionary
func _initialize() -> void:
	create_timer(240).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func cancel() -> void:
	for unit in b.units:
		if int(unit.owner)==2: b.world.command_groups._cancel_unit_command(unit)
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map="chibic1"
	b=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false);b.cli_mode=true
	infantry=b.units.filter(func(unit):return int(unit.owner)==2 and int(unit.unit)==32)[0].duplicate(true)
	hq=b.units.filter(func(unit):return int(unit.owner)==2 and int(unit.unit)==1)[0].duplicate(true)
	for tick in range(2910):
		b.world.battle_simulation._sim_step(b.SIM_DT)
		assert(b.units.all(func(unit):return int(unit.owner)!=2 or str(unit.state)!="attack"),"C1 must not send a cross-map interception before the first assault cycle")
		if tick%300==0: await process_frame
	assert(b.game_end==0 and b.sim_tick==2910)
	b.world.battle_simulation._sim_step(b.SIM_DT)
	var attacks: Array=b.units.filter(func(unit):return int(unit.owner)==2 and str(unit.state)=="attack")
	assert(attacks.size()==23,"C1 dispatches its eligible original troops at tick 2911")
	var first_player: Dictionary=b.units.filter(func(unit):return int(unit.owner)==3 and not unit.is_building)[0]
	for unit in attacks:
		if (unit.officer as Dictionary).is_empty(): assert(unit.target.uid==first_player.uid,"Ordinary units use player slot order")
		else: assert(int(unit.target.unit)==1,"Heroes prefer the headquarters")
	print("AI RESEARCH C1 PASS first assault tick2911 / no tick1230 rush /23 original combatants / slot-order targets")
	save_point_checks()
	gate_checks()
	intercept_checks()
	b.scene.ready_to_save=false;b.free();done=true;print("AI RESEARCH PASS");quit()
func save_point_checks() -> void:
	var cell: Vector2i=b.world.spatial_index._free_unit_cell(Vector2i(60,100),0,-1,32)
	assert(cell.x>=0)
	assert(b.ai.set_retreat_point(2,b.nav.anchor_of(cell.x,cell.y)))
	b.ai._retreat_clock[2]=41;b.ai._think[2]=40
	var game: Node=root.get_node("Game")
	var saved: Dictionary=game.snapshot(b.units,b.world.economy.player_resources(),b.scene_controller._save_extra())
	var phase: Dictionary=b.ai.snapshot()
	b.world.battle_simulation._sim_step(b.SIM_DT)
	var expected: String=game.save_checksum(b.saver.continuation_snapshot(game))
	assert(b.saver.apply_snapshot(saved),"Explicit retreat destination must pass complete world restore")
	assert(b.ai.snapshot().retreatPoints==phase.retreatPoints and b.ai.snapshot().retreatClock==phase.retreatClock)
	b.world.battle_simulation._sim_step(b.SIM_DT)
	assert(game.save_checksum(b.saver.continuation_snapshot(game))==expected,"Restored retreat timing must resume identically")
	print("AI RESEARCH SAVE PASS full world / explicit retreat point /42-thought boundary / identical continuation")
func gate_checks() -> void:
	cancel();b.ai=AI.new(b.world)
	b.scenario_sides[0].init=[0,1,1];b.scenario_sides[1].init=[0,4,1]
	b.economy.write(3,{"gold":15000,"food":1000,"wood":1000,"stone":1000})
	b.ai._assault[2]=71;b.ai._assault_maybe(2)
	assert(b.units.any(func(unit):return int(unit.owner)==2 and unit.state=="attack"),"Wait uses the player's own gate, not the AI's gate")
	cancel();b.scenario_sides[0].init=[0,4,1];b.scenario_sides[1].init=[0,2,1]
	b.ai._assault[2]=71;b.ai._assault_maybe(2)
	assert(b.units.all(func(unit):return int(unit.owner)!=2 or unit.state!="attack"))
	b.scenario_mission=14;b.ai._assault[2]=71;b.ai._assault_maybe(2)
	assert(b.units.any(func(unit):return int(unit.owner)==2 and unit.state=="attack"),"Mission14 bypasses waiting")
	cancel();b.scenario_mission=17
	for unit in b.units:
		if int(unit.owner)==3:unit.owner=0
	b.ai._assault[2]=40;b.ai._assault_maybe(2)
	assert(not b.ai._assault_period.has(2),"Low player count must not shorten a running cycle")
	b.ai._assault[2]=71;b.ai._assault_maybe(2)
	assert(b.ai._assault_period[2]==6 and b.ai._assault[2]==0)
	print("AI RESEARCH GATES PASS separate gates / mission14 bypass / next-cycle urgency")
func copy_unit(uid: int, owner: int, point: Vector2, kind: int = 32) -> Dictionary:
	var unit: Dictionary=infantry.duplicate(true)
	unit.uid=uid;unit.owner=owner;unit.unit=kind;unit.ax=point.x;unit.ay=point.y
	unit.officer={};unit.group_officer=-1;unit.state="idle";unit.target=null;unit.path=[];unit.pi=0
	return unit
func intercept_checks() -> void:
	var base: Dictionary=hq.duplicate(true);base.uid=500;base.ax=1000;base.ay=1000
	var target:=copy_unit(501,3,Vector2(4000,2000))
	var focus:=copy_unit(502,2,Vector2(2500,2000))
	var near:=copy_unit(503,2,Vector2(1089,1089))
	var far:=copy_unit(504,2,Vector2(1091,1000))
	var worker:=copy_unit(505,2,Vector2(1050,1000),30)
	b.units=[base,focus,near,far,worker,target];b.world.spatial_index._rebuild_unit_index();b.ai=AI.new(b.world)
	assert(b.world.ai_orders.ai_focus_unit(2).is_empty(),"An idle unit is not evidence of enemy contact")
	focus.target=target;focus.state="attack"
	for thought in range(15):
		b.ai._intercept_near(2);b.ai._intercept_near(1)
	assert(near.state=="idle")
	var snapshot: Dictionary=b.ai.snapshot();b.ai.restore(snapshot)
	b.ai._intercept_near(2)
	assert(near.state=="attack" and near.target.uid==target.uid,"Warmup expires once; square +/-90px includes the corner")
	assert(far.state=="idle" and worker.state=="idle","No 8x radius expansion or worker hijack")
	near.state="idle";near.target=null;b.ai._intercept_near(2)
	assert(near.state=="attack","Interception stays enabled after warmup")
	focus.target=null;near.target=null;near.state="idle";b.ai._intercept_near(2)
	assert(near.state=="idle","No global target scan when the army has no contact")
	var second:=copy_unit(506,3,Vector2(1001,1000))
	assert(Targets.select([target,second],near,3,17,270).uid==target.uid)
	print("AI RESEARCH INTERCEPT PASS shared saturating warmup / HQ square90px / existing contact / ordinary troops / no remote auto-target")
