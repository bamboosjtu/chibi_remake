extends SceneTree
class WarmupHarness extends "res://testing/full_battle_benchmark.gd":
	func _ready() -> void:pass
var done:=false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	var script=load(get_script().resource_path.get_base_dir().path_join("bench_full_battle.gd"))
	root.get_node("Game").current_map="chibic1"
	var b=load("res://main.tscn").instantiate();root.add_child(b);b.cli_mode=true
	assert(script.workload_valid(b))
	b.view.briefing.open();assert(paused and not script.workload_valid(b))
	var tick: int=b.sim_tick;var rendered:=Engine.get_process_frames()
	for i in range(10):await process_frame
	assert(Engine.get_process_frames()>rendered and b.sim_tick==tick)
	b.commands.world._sim_step(b.SIM_DT)
	assert(b.sim_tick==tick+1 and not script.workload_valid(b),"Manual logic cannot legitimize paused FPS")
	b.view.briefing.close();assert(not paused and script.workload_valid(b))
	var running_tick: int=b.sim_tick
	await create_timer(0.12).timeout
	assert(b.sim_tick>running_tick,"Unpaused measurement must advance actual frame-driven simulation")
	b.set_process(false)
	var fixed_tick: int=b.sim_tick;var report: Dictionary={}
	var harness:=WarmupHarness.new();root.add_child(harness)
	assert(await harness._start_live_measurement(b,report))
	assert(b.sim_tick==fixed_tick and report.frameInitialTick==fixed_tick and report.renderWarmupPreservedSimulation,"Renderer warmup must preserve the exact simulation start")
	assert(not str(report.frameInitialStateChecksum).is_empty())
	harness.free()
	b.game_end=1;assert(not script.workload_valid(b))
	b.scene.ready_to_save=false;b.free();done=true;print("BENCHMARK GUARD PASS real briefing pause / rendered frames without gameplay rejected / manual-tick bypass rejected / ended battle rejected");quit()
