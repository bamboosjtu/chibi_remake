extends Node
## Shared workload: the source launcher and the shipped PCK use this same driver.
var root:
	get: return get_tree().root
var paused:
	get: return get_tree().paused
var process_frame:
	get: return get_tree().process_frame
func create_timer(seconds: float):return get_tree().create_timer(seconds)
func quit(code: int=0):get_tree().quit(code)
func _ready() -> void:_initialize()
## Full-battle benchmark: real scenario, AI, combat, projectiles, economy,
## rendering and terrain streaming. Run through tools/bench_full_battle.ps1 so
## the host can also record the process peak working set.

const Config = preload("res://simulation/battle_config.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
var script_kernel := false
var capacity_stress := false
var profile_only := false
var profile_units := false
var done := false
var map_id := "chibic17"
var target_units := 800
var ticks := 600
var frames := 300
var engage := 240
var use_ai := true
var use_view := true
var command_latencies: Array=[]
var command_submissions := {}
var engaged_actual := 0
var last_progress_usec := 0
var output_path := "user://full-battle-bench.json"

func _initialize() -> void:
	create_timer(1800).timeout.connect(func():
		if not done: quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-map="): map_id = arg.substr(12)
		elif arg.begins_with("--bench-units="): target_units = maxi(50, int(arg.substr(14)))
		elif arg.begins_with("--bench-ticks="): ticks = maxi(60, int(arg.substr(14)))
		elif arg.begins_with("--bench-frames="): frames = maxi(30, int(arg.substr(15)))
		elif arg.begins_with("--bench-engage="): engage = maxi(0, int(arg.substr(15)))
		elif arg == "--bench-script-kernel": script_kernel=true
		elif arg == "--bench-capacity": capacity_stress=true
		elif arg == "--bench-profile": profile_units=true
		elif arg == "--bench-logic-only": profile_only=true
		elif arg == "--bench-profile-only": profile_only=true;profile_units=true
		elif arg == "--bench-no-ai": use_ai = false
		elif arg == "--bench-no-view": use_view = false
		elif arg.begins_with("--bench-output="): output_path = arg.substr(15)
	if "--no-intro" not in OS.get_cmdline_user_args():
		_invalid("Benchmark requires --no-intro");return
	if not Array(OS.get_cmdline_user_args()).any(func(arg):return str(arg).begins_with("--save-test-id=")):
		_invalid("Benchmark requires an isolated --save-test-id");return
	run.call_deferred()

func _mobile_count(battle: Node2D) -> int:
	var count := 0
	for unit in battle.units:
		if bool(unit.get("alive", false)) and not bool(unit.get("is_building", false)) and int(unit.get("unit", 0)) >= 27:
			count += 1
	return count

func _fill(battle: Node2D) -> int:
	var owners: Array = [int(battle.player_owner)]
	for owner in battle._modules["ai_economy"].ai_owners():
		if int(owner) != int(battle.player_owner) and not owners.has(int(owner)): owners.append(int(owner))
	if capacity_stress:
		owners=[]
		for side in battle.scenario_sides:
			if int(side.owner)>0 and not owners.has(int(side.owner)):owners.append(int(side.owner))
		var pop:=population(battle);target_units=_mobile_count(battle)
		for owner in owners:target_units+=maxi(0,200-int(pop.get(str(owner),{}).get("entities",0)))
	else:
		for unit in battle.units:
			var owner := int(unit.get("owner", 0))
			if owner > 0 and not owners.has(owner): owners.append(owner)
		for owner in [1, 2, 3, 4]:
			if not owners.has(owner): owners.append(owner)
	var terrain_w := float(battle.map_data.get("terrainW", 4000))
	var terrain_h := float(battle.map_data.get("terrainH", 3000))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	var spawned := 0
	var attempts := 0
	while _mobile_count(battle) < target_units and attempts < target_units * 200:
		attempts += 1
		var owner: int = int(owners[attempts % owners.size()])
		var unit_id: int = int(Roles.ids("officers")[attempts % Roles.ids("officers").size()])
		var ax := rng.randf_range(120.0, terrain_w - 120.0)
		var ay := rng.randf_range(120.0, terrain_h - 120.0)
		if battle.commands.world._spawn_unit(unit_id, owner, ax, ay, false):
			spawned += 1
	# Give a bounded share of the troops an enemy so pathfinding, attacks and
	# projectiles run, while the rest stay as AI reserve.
	battle.visibility.update(battle.units,battle.player_owner)
	var engaging := 0
	for unit in battle.units:
		if engaging >= engage: break
		if not bool(unit.get("alive", false)) or bool(unit.get("is_building", false)): continue
		if int(unit.get("unit", 0)) in Roles.ids("officers") and str(unit.get("state", "")) in ["idle", ""]:
			var enemy: Dictionary = battle.commands.military._nearest_enemy(unit, 100000.0)
			if not enemy.is_empty():
				unit.target = enemy
				unit.state = "attack"
				engaging += 1
	engaged_actual=engaging
	return spawned

func _percentile(sorted_values: Array, percentile: float) -> float:
	if sorted_values.is_empty(): return 0.0
	var index := clampi(int(roundf(percentile * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1)
	return float(sorted_values[index])

static func workload_valid(battle: Node2D) -> bool:
	return not battle.get_tree().paused and battle.game_end==0 and battle.is_processing()

func _invalid(reason: String) -> void:
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"validWorkload":false,"error":reason}));file.close()
	push_error(reason);done=true;quit(1)

func _probe_command(battle: Node2D) -> bool:
	var at:=Time.get_ticks_usec()
	if battle.commands.session.submit_command("assign_group", -1, 10) <= 0: return false
	command_submissions[int(battle.player_commands.sequence)] = at
	return true

func _command_finished(command: Dictionary, result: String) -> void:
	var id := int(command.sequence)
	if not command_submissions.has(id): return
	if result == "applied":
		command_latencies.append(float(Time.get_ticks_usec() - int(command_submissions[id])) / 1000.0)
	command_submissions.erase(id)

func _progress(phase: String, sample: int, battle: Node2D) -> void:
	var now:=Time.get_ticks_usec()
	if now-last_progress_usec<2000000:return
	last_progress_usec=now
	var file:=FileAccess.open(output_path+".progress.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"phase":phase,"sample":sample,"tick":battle.sim_tick,"paused":paused,"gameEnd":battle.game_end,"accumulator":battle.sim_acc}));file.close()

func run() -> void:
	preload("res://simulation/native/math_kernel.gd").force_script=script_kernel
	var rules_fingerprint: String=preload("res://app/saves/rules_identity.gd").current()
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map=map_id
	var battle: Node2D=load("res://main.tscn").instantiate();root.add_child(battle);battle.cli_mode=true;battle.set_process(false)
	for i in range(30):await process_frame
	if paused or battle.game_end!=0:_invalid("Opening or completion paused/stopped the battle");return
	battle.set_process(false)
	if not use_ai:battle.ai=null
	if not use_view and battle.view!=null:battle.view.free();battle.view=null
	var spawned:=_fill(battle);var measured_units:=_mobile_count(battle)
	if battle.view!=null:battle.view.queue_world_visuals();battle.view.flush_visuals(false)
	if engaged_actual<engage:_invalid("Actual engaged units below the requested workload");return
	var navigation_begin:=Time.get_ticks_usec()
	battle.nav.warm_runtime_shapes()
	var navigation_warm_ms: float=(Time.get_ticks_usec()-navigation_begin)/1000.0
	_progress("warmup",0,battle)
	# Keep the same fighting workload alive throughout both measurement phases.
	for unit in battle.units:
		unit.hp=maxf(float(unit.hp),10000000.0);unit.maxhp=unit.hp
	for i in range(60):battle.commands.world._sim_step(Config.SIM_DT)
	battle._modules.unit_actions.profile_enabled=profile_units
	battle._modules.unit_actions.profile.clear()
	battle._modules.battle_simulation.profile_enabled=profile_units
	battle._modules.battle_simulation.timing_enabled=true
	battle.nav.set_profiling(true)
	battle._modules.battle_simulation.profile.clear()
	battle._modules.battle_simulation.native_unit_profile.clear()
	var path_begin: Dictionary=battle.nav.performance_counters()
	var visual_begin: Dictionary=battle.view.performance_counters() if battle.view!=null else {}
	var times: Array=[]
	for i in range(ticks):
		if i%30==0:_progress("logic",i,battle)
		if paused or battle.game_end!=0:_invalid("Simulation stopped during logic measurement");return
		if i%10==0:await _logic_frame(battle)
		var before: int=battle.sim_tick;var begin:=Time.get_ticks_usec()
		battle.commands.world._sim_step(Config.SIM_DT)
		if battle.sim_tick!=before+1:_invalid("Logic measurement did not execute exactly one tick");return
		times.append(float(Time.get_ticks_usec()-begin)/1000.0)
	var path_end: Dictionary=battle.nav.performance_counters()
	var visual_end: Dictionary=battle.view.performance_counters() if battle.view!=null else {}
	var sorted:=times.duplicate();sorted.sort();var total:=0.0
	for value in times:total+=value
	var report: Dictionary={"protocolVersion":4,"simulationKernel":"native" if preload("res://simulation/native/math_kernel.gd").get_kernel()!=null else "script","navigationWarmupMs":navigation_warm_ms,"profilingEnabled":profile_units,"workloadMode":"scenario-capacity" if capacity_stress else "legacy-synthetic","initialTick":0,"map":map_id,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"unitsTarget":target_units,"unitsMeasured":measured_units,"spawned":spawned,"engaged":engaged_actual,"engagedTarget":engage,"rulesRevision":rules_fingerprint,"engine":Engine.get_version_info().string,"engineBuild":"debug" if OS.is_debug_build() else "release","viewport":[1920,1080],"persistentHitPoints":10000000,"ticks":ticks,"logicAverageMs":total/times.size(),"logicP50Ms":_percentile(sorted,0.5),"logicP95Ms":_percentile(sorted,0.95),"logicP99Ms":_percentile(sorted,0.99),"logicMaxMs":sorted.back(),"logicBudgetMs":1000.0/30.0}
	report.merge({"pathCallsPerTick":float(path_end.calls-path_begin.calls)/ticks,"pathMsPerTick":float(path_end.microseconds-path_begin.microseconds)/ticks/1000.0,"pathSmoothMsPerTick":float(path_end.smoothMicroseconds-path_begin.smoothMicroseconds)/ticks/1000.0,"pathSearchMsPerTick":float(path_end.searchMicroseconds-path_begin.searchMicroseconds)/ticks/1000.0,"updateVisualMsPerTick":float(visual_end.get("syncMicroseconds",0)-visual_begin.get("syncMicroseconds",0))/ticks/1000.0})
	_record_profile(battle,report)
	report["population"]=population(battle)
	if profile_only:
		report["diagnosticOnly"]=true
		var diagnostic:=FileAccess.open(output_path,FileAccess.WRITE);diagnostic.store_string(JSON.stringify(report,"  "));diagnostic.close()
		battle.scene.ready_to_save=false;battle.free();done=true;quit();return
	if not await _start_live_measurement(battle,report):return
	if not workload_valid(battle):_invalid("Rendering phase has no running gameplay process");return
	visual_begin=battle.view.performance_counters() if battle.view!=null else {}
	path_begin=battle.nav.performance_counters()
	var simulation_begin: int=battle._modules.battle_simulation.tick_microseconds
	var view_time: int=battle._modules.scene_controller.view_microseconds;var hud_time: int=battle._modules.scene_controller.hud_microseconds;var interpolate_time: int=battle._modules.scene_controller.interpolation_microseconds
	var tick_begin: int=battle.sim_tick;var backlog_begin: float=battle.sim_acc;var backlog_max:=backlog_begin
	var at:=Time.get_ticks_usec();var previous:=at;var durations: Array=[]
	for i in range(frames):
		if i%5==0:_progress("frames",i,battle)
		if i%10==0 and not _probe_command(battle): _invalid("Benchmark command admission failed"); return
		await process_frame
		if not workload_valid(battle):_invalid("Gameplay paused or ended during frame sampling");return
		var now:=Time.get_ticks_usec();durations.append(float(now-previous)/1000.0);previous=now
		backlog_max=maxf(backlog_max,float(battle.sim_acc))
	var seconds:=float(Time.get_ticks_usec()-at)/1000000.0
	var advanced: int=battle.sim_tick-tick_begin;durations.sort();command_latencies.sort()
	if advanced<=0 or command_latencies.size()<ceili(float(frames)/10.0):_invalid("Frames were produced without all simulation/input work");return
	visual_end=battle.view.performance_counters() if battle.view!=null else {}
	path_end=battle.nav.performance_counters()
	report.merge({"frameSimulationMsPerTick":float(battle._modules.battle_simulation.tick_microseconds-simulation_begin)/advanced/1000.0,"frameSimulationMsPerFrame":float(battle._modules.battle_simulation.tick_microseconds-simulation_begin)/frames/1000.0,"cameraHoverMsPerFrame":float(battle._modules.scene_controller.view_microseconds-view_time)/frames/1000.0,"hudMsPerFrame":float(battle._modules.scene_controller.hud_microseconds-hud_time)/frames/1000.0,"interpolationMsPerFrame":float(battle._modules.scene_controller.interpolation_microseconds-interpolate_time)/frames/1000.0,"realtimeLogicBudgetMs":battle.clock.period()*1000.0,"framePathCallsPerTick":float(path_end.calls-path_begin.calls)/advanced,"framePathMsPerTick":float(path_end.microseconds-path_begin.microseconds)/advanced/1000.0,"updateVisualMsPerFrame":float(visual_end.get("syncMicroseconds",0)-visual_begin.get("syncMicroseconds",0))/frames/1000.0,"fogUpdateMsPerFrame":float(visual_end.get("fogMicroseconds",0)-visual_begin.get("fogMicroseconds",0))/frames/1000.0,"visualSyncsPerFrame":float(visual_end.get("syncCalls",0)-visual_begin.get("syncCalls",0))/frames})
	report.merge({"validWorkload":true,"frames":frames,"fps":frames/maxf(seconds,0.001),"frameP50Ms":_percentile(durations,0.5),"frameP95Ms":_percentile(durations,0.95),"frameMaxMs":durations.back(),"simulationTicksAdvanced":advanced,"measurementSeconds":seconds,"ticksPerSecond":advanced/seconds,"targetTicksPerSecond":1.0/battle.clock.period(),"simAccumulatorBegin":backlog_begin,"simAccumulatorEnd":battle.sim_acc,"simAccumulatorMax":backlog_max,"wallClockBehindSeconds":maxf(0.0,seconds-advanced*battle.clock.period()),"unitsAtFrameEnd":_mobile_count(battle),"commandSamples":command_latencies.size(),"commandLatencyP95Ms":_percentile(command_latencies,0.95),"commandLatencyScope":"in-game command queue; OS input delivery excluded","pausedAtEnd":paused,"gameEnd":battle.game_end})
	report.merge({"memoryStaticBytes":Performance.get_monitor(Performance.MEMORY_STATIC),"memoryStaticMaxBytes":Performance.get_monitor(Performance.MEMORY_STATIC_MAX),"videoMemoryBytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"renderObjects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:_invalid("Cannot write benchmark report");return
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("FULL BATTLE BENCH ",JSON.stringify(report));battle.scene.ready_to_save=false;battle.free();done=true;quit()

func population(battle: Node2D) -> Dictionary:
	var sides: Dictionary={}
	for unit in battle.units:
		var key:=str(int(unit.owner))
		if not sides.has(key):sides[key]={"entities":0,"mobile":0,"buildings":0,"officers":0,"dying":0}
		sides[key].entities+=1
		if unit.is_building:sides[key].buildings+=1
		else:sides[key].mobile+=1
		if not (unit.get("officer",{}) as Dictionary).is_empty():sides[key].officers+=1
		if float(unit.die_t)>=0:sides[key].dying+=1
	return sides

func _record_profile(battle: Node2D, report: Dictionary) -> void:
	report["renderingMethod"]=RenderingServer.get_current_rendering_method()
	report["renderingDriver"]=RenderingServer.get_current_rendering_driver_name()
	report["nativeUnitBatch"]=preload("res://simulation/native/math_kernel.gd").get_kernel()!=null and battle._modules.battle_simulation.native_unit_port!=null
	report["minimapBackend"]="gpu-instanced" if battle.view!=null and battle.view._ui.minimap.gpu_markers else "cpu"
	report["unitProfileUsec"]=battle._modules.unit_actions.profile.duplicate()
	report["worldProfileUsec"]=battle._modules.battle_simulation.profile.duplicate()
	for key in battle._modules.battle_simulation.native_unit_profile:report.unitProfileUsec[key]=int(report.unitProfileUsec.get(key,0))+int(battle._modules.battle_simulation.native_unit_profile[key])

func _logic_frame(battle: Node2D) -> void:
	if battle.view!=null:battle.view.flush_visuals(false)
	await process_frame

func _start_live_measurement(battle: Node2D, report: Dictionary) -> bool:
	battle._modules.unit_actions.profile_enabled=false
	battle._modules.battle_simulation.profile_enabled=false
	battle._modules.battle_simulation.timing_enabled=false
	battle.nav.set_profiling(false)
	var game: Node=root.get_node("Game")
	var checksum: String=game.save_checksum(battle.saver.continuation_snapshot(game))
	for i in range(30):await _logic_frame(battle)
	if checksum!=game.save_checksum(battle.saver.continuation_snapshot(game)):
		_invalid("Rendering warmup modified simulation state");return false
	report["frameInitialTick"]=battle.sim_tick
	report["frameInitialStateChecksum"]=checksum
	report["renderWarmupPreservedSimulation"]=true
	battle._modules.battle_simulation.timing_enabled=true
	battle.nav.set_profiling(true)
	battle.player_commands.command_finished.connect(_command_finished)
	battle.sim_acc=0;battle.set_process(true)
	return true
