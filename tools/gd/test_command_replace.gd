extends SceneTree
var done := false
var b: Node2D
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func dirty(w: Dictionary, state: String, target: Dictionary) -> void:
	w.state=state;w.target=target;w.gather_obj=target;w.build_target=target;w.repair_target=target;w.board_target=target
	w.path=[Vector2(w.ax+100,w.ay)];w.pi=0;w.cool=0.8;w.repath=0.5
	w.gather_ticks=96;w.delivery_ticks=3;w.gather_t=3.2;w.rest_t=0.2;w.build_t=0.1
	w.repath_to=Vector2(0,0);w.blocked_n=3;w.hold=true
	w.carry=137;w.carry_kind="wood"

func clean(w: Dictionary) -> bool:
	for key in ["gather_obj","build_target","repair_target","board_target"]:
		if w.get(key)!=null:return false
	for key in ["gather_ticks","delivery_ticks","gather_t","rest_t","build_t","cool","blocked_n"]:
		if w.get(key,0)!=0:return false
	return not w.has("repath_to") and w.carry==137 and w.carry_kind=="wood"

func run() -> void:
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	await process_frame;await process_frame
	b.view.event_view.restore_history()
	var workers:Array=b.units.filter(func(u):return u.owner==b.player_owner and int(u.unit)==30)
	var w:Dictionary=workers[0]
	var enemy:Dictionary=b.units.filter(func(u):return u.owner!=b.player_owner and int(u.owner)!=0 and not u.is_building)[0]
	var destination:=Vector2(w.ax,w.ay)
	b.selected=[w]
	for state in ["move","attack","gather","deliver","build","repair","rest","board"]:
		for action in ["move","attack"]:
			dirty(w,state,enemy)
			if action=="move":b.commands._move_selected_to(destination)
			else:assert(b.commands._attack_selected(enemy)==1)
			assert(clean(w))
			assert(w.state==action and (w.target==enemy if action=="attack" else w.target==null))
	# Shift只参与选择；右键新目标仍替换，未追加命令。
	var shift:=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.pressed=true;Input.parse_input_event(shift)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true
	event.position=b.get_canvas_transform()*destination
	dirty(w,"build",enemy);b._unhandled_input(event)
	assert(w.state=="build", "input must enqueue rather than execute in the event callback")
	b.player_commands.pump();assert(clean(w));assert(w.state=="move")
	shift=shift.duplicate();shift.pressed=false;Input.parse_input_event(shift)
	print("COMMAND REPLACE PASS 8 old actions x move-attack / Shift right-click / cargo preserved")
	# 共享工地被重新派工的工人放下；其他工人继续施工，无退款、无销毁。
	var site:Dictionary=b.units.filter(func(u):return u.owner==b.player_owner and u.is_building)[0]
	site.site=true;site.hp=100;site.build_cost={"gold":100,"wood":100}
	var other:Dictionary=workers[1]
	w.build_target=site;w.state="build";other.build_target=site;other.state="build"
	var before:Dictionary=b.commands._resources().duplicate()
	b.commands._move_selected_to(destination)
	assert(site.alive and site.site and site.hp==100 and other.build_target==site and other.state=="build")
	assert(b.commands._resources()==before)
	# 采集指令也须解除修理/休息/上船引用；负载保留，先交货再采新资源。
	var resource:Dictionary=b.decor_targets.filter(func(o):return o.alive and int(o.unit)==102)[0]
	dirty(w,"repair",site);b.commands._begin_gather(w,resource,[destination])
	assert(w.state=="deliver" and w.gather_obj==resource and w.build_target==null and w.repair_target==null and w.board_target==null)
	assert(w.carry==137 and w.delivery_ticks==0)
	b.commands._move_selected_to(destination);assert(clean(w))
	var uid:int=w.uid
	var game:=root.get_node("Game")
	assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
	assert(b.saver.apply_snapshot(game.load_save()))
	w=b.units.filter(func(u):return u.uid==uid)[0]
	assert(clean(w));assert(w.state=="move")
	print("COMMAND SAVE PASS shared site preserved / no refund / gather replacement / new command persists")
	b.free();done=true;quit()
