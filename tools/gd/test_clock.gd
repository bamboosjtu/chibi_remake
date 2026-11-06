extends SceneTree
var done:=false
func _initialize() -> void:
 create_timer(60).timeout.connect(func():
  if not done:quit(1))
 run.call_deferred()
func run() -> void:
 var game:=root.get_node("Game")
 game.current_map="chibil1"
 var b:Node2D=load("res://main.tscn").instantiate()
 root.add_child(b);b.set_process(false);b.cli_mode=true;b.ai=null
 assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
 var initial:Dictionary=game.load_save()
 for speed in range(4):
  for fps in [10,30,60,144]:
   assert(b.saver.apply_snapshot(initial))
   b.ai=null
   assert(b.commands.set_sim_speed(speed))
   for frame in range(fps*6):b._process(1.0/float(fps))
   while b.sim_acc+0.000000001>=b.clock.period():b._process(0)
   assert(b.sim_tick==int(round(6.0/b.clock.period())),"tick count changes with rendering FPS")
  print("CLOCK PASS speed=",speed," period=",b.clock.period()," ticks=",b.sim_tick," at10/30/60/144fps")
 # 长帧超过每帧预算后不能丢tick。
 assert(b.saver.apply_snapshot(initial));b.ai=null;b.commands.set_sim_speed(3)
 b._process(1.0)
 assert(b.sim_tick==b.SIM_MAX_CATCHUP and b.sim_acc>0.8)
 while b.sim_acc+0.000000001>=b.clock.period():b._process(0)
 assert(b.sim_tick==50 and b.sim_acc<0.000001)
 b.commands.set_sim_speed(0);b.sim_acc=0.05;b.commands.set_sim_speed(3)
 assert(is_equal_approx(b.sim_acc,0.01))
 assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
 var snapshot:Dictionary=game.load_save()
 b.commands.set_sim_speed(0);b.sim_acc=0
 assert(b.saver.apply_snapshot(snapshot) and b.clock.speed_index==3 and is_equal_approx(b.sim_acc,0.01))
 var invalid:Dictionary=snapshot.duplicate(true)
 invalid.simulation.speedIndex=99
 assert(not b.saver.apply_snapshot(invalid) and b.clock.speed_index==3)
 var legacy:Dictionary=snapshot.duplicate(true)
 legacy.simulation.erase("speedIndex")
 assert(b.saver.apply_snapshot(legacy) and b.clock.speed_index==2 and is_equal_approx(b.sim_acc,0.009))
 print("CLOCK SAVE PASS backlog preserved / phase-preserving speed switch / save / invalid atomic / old save default")
 # simtest 目标3tick：单帧补5步的预算不得越过取样时刻。
 b.sim_tick=0;b.sim_acc=0;b.simtest_seconds=0.1
 b._process(1.0)
 assert(b.sim_tick==3)
 b.free();done=true;quit()
