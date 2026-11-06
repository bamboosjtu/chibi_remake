extends SceneTree
## Native HD comparison: same position history, old cadence versus research cadence.
var output:="user://movement-review"
var b:Node2D
var actors:Array=[]
var done:=false
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func label_at(value:String,point:Vector2,font_size:=26) -> void:
	var label:=Label.new();root.add_child(label);label.text=value;label.position=point
	label.add_theme_font_size_override("font_size",font_size)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	RenderingServer.set_default_clear_color(Color("18212b"))
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	await process_frame;await process_frame
	if "--battlefield" in OS.get_cmdline_user_args():
		await capture_battlefield();done=true;quit();return
	b.cam.enabled=false;b.cam=null;b.view.cam=null
	for child in b.view.get_children():
		if child is CanvasItem:child.hide()
		if child is CanvasLayer:child.hide()
		child.set_process(false)
	# The fixture has no walls or interaction targets; production navigation is unchanged.
	var walk:Array=[];walk.resize(50*100);walk.fill(1)
	var layout:Dictionary={"rows":50,"cols":100,"terrainW":2244,"terrainH":1122,"tileW":44,"walkable":walk,"terrainWalkable":walk}
	b.nav.setup(layout)
	var stage:=Node2D.new();root.add_child(stage)
	var types:=[29,30,32,36,45,44]
	for i in range(types.size()):
		for side in range(2):
			var foot:=Vector2(150+side*930,205+i*135)
			assert(b.commands.world._spawn_unit(types[i],b.player_owner,foot.x,foot.y,true))
			var unit:Dictionary=b.units.back()
			unit.ax=foot.x;unit.ay=foot.y;unit.dir=0;unit.move_facing=0;unit.walk_tick=0
			unit.state="move";unit.path=[foot+Vector2(290,0),foot+Vector2(180,-55),foot];unit.pi=0
			var wrapper:=Node2D.new();stage.add_child(wrapper);wrapper.scale=Vector2(2,2)
			unit.review_wrapper=wrapper;b.view.unit_nodes(unit).spr.reparent(wrapper,false);b.view.unit_nodes(unit).spr.show()
			b.view.unit_nodes(unit).diamond.hide();b.view.unit_nodes(unit).hbar.hide();actors.append(unit)
		label_at(b.commands.world._unit_name(types[i]),Vector2(30,170+i*135),22)
		label_at(b.commands.world._unit_name(types[i]),Vector2(960,170+i*135),22)
	for unit in b.units:
		if unit not in actors and b.view.unit_nodes(unit).get("spr")!=null:b.view.unit_nodes(unit).spr.hide()
	b.units=actors;b.selected=[];b.commands.world._rebuild_unit_index()
	label_at("原有动画：10 帧/秒，朝向立即切换",Vector2(75,35),30)
	label_at("修复：每两次更新推进一帧，逐方向转身",Vector2(990,35),30)
	label_at("同一条路径、相同位移速度；灰线为脚底轨迹。",Vector2(600,1010),22)
	for unit in actors:
		var line:=Line2D.new();stage.add_child(line);line.default_color=Color("536475");line.width=1
		line.points=PackedVector2Array([Vector2(unit.ax,unit.ay),unit.path[0],unit.path[1],unit.path[2]])
	var accumulator:=0.0
	for frame in range(420):
		accumulator+=1.0/60.0
		while accumulator>=b.clock.period():
			accumulator-=b.clock.period();b.view.capture_motion()
			for unit in actors:b.commands.orders._step_unit(unit,b.SIM_DT);b.commands.world._update_visual(unit)
		b.view.interpolate_motion(accumulator/b.clock.period())
		for i in range(0,actors.size(),2):
			var unit:Dictionary=actors[i]
			b.view.set_frame(unit,b.commands.military._clip_frame(unit,"walk" if unit.moved else "turn",int(unit.dir),int(float(unit.anim)*10)))
		for unit in actors:
			unit.review_wrapper.position=-(b.view.unit_nodes(unit).spr.position+Vector2(float(unit.w)*0.5,float(unit.h)))
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("frame-%04d.png"%frame))==OK)
	print("MOVEMENT NATIVE PASS 420 native HD frames / six types / identical paths / start-corner-reversal / old-new comparison")
	done=true;quit()

func capture_battlefield() -> void:
	for child in b.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			while not (child._pending.is_empty() and not child._wanted.is_empty() and child._wanted.keys().all(func(k):return child.active.has(k))):
				await create_timer(0.01,true).timeout
	var leader:Dictionary=b.selected[0]
	var origin:=Vector2(float(leader.ax),float(leader.ay))
	b.commands.orders._move_selected_to(origin+Vector2(280,-120))
	var accumulator:=0.0
	for frame in range(420):
		if frame==210:b.commands.orders._move_selected_to(origin)
		accumulator+=1.0/60.0
		while accumulator>=b.clock.period():
			accumulator-=b.clock.period();b.commands.world._sim_step(b.SIM_DT)
		if frame%6==0:b.commands.session._view_hud()
		b.view.interpolate_motion(accumulator/b.clock.period())
		await process_frame;await RenderingServer.frame_post_draw
		# JPEG keeps offline full-terrain capture from stalling on PNG compression.
		assert(root.get_texture().get_image().save_jpg(output.path_join("frame-%04d.jpg"%frame),0.94)==OK)
	print("BATTLEFIELD MOVEMENT NATIVE PASS commander-worker team / actual world paths / order reversal / 420 interpolated HD frames")
