extends SceneTree
## Exercise the rendered mask after transactional load, including paused loading.
var battle: Node2D
var output := ""
var actors: Array = []

func _initialize() -> void:
	run.call_deferred()

func hidden_land(avoid: Array) -> Vector2:
	for x in range(8,int(battle.map_data.rows)-8,7):
		for y in range(8,int(battle.map_data.cols)-8,7):
			var cell:=Vector2i(x,y)
			if battle.nav.is_solid(cell): continue
			var point: Vector2=battle.nav.anchor_of(x,y)
			if battle.visibility.is_visible(point): continue
			if avoid.any(func(p):return point.distance_to(p)<650): continue
			return point
	assert(false,"fixture needs an unexplored land cell")
	return Vector2.ZERO

func mask_alpha(point: Vector2) -> float:
	var image: Image=battle.view.fog_sprite.texture.get_image()
	return image.get_pixel(floori(point.x/22),floori(point.y/11)).a

func capture(name: String) -> void:
	if output=="": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)

func restored_mask() -> void:
	var hero: Dictionary=battle.selected[0]
	var home:=Vector2(hero.ax,hero.ay)
	var points: Array=battle.units.filter(func(u):return int(u.owner)==battle.player_owner and bool(u.alive)).map(func(u):return Vector2(u.ax,u.ay))
	var visible:=hidden_land(points)
	points.append(visible)
	var remembered:=hidden_land(points)
	points.append(remembered)
	var unknown:=hidden_land(points)
	var scout: Dictionary={"uid":999999,"alive":true,"die_t":-1,"owner":battle.player_owner,"is_building":false,"ax":remembered.x,"ay":remembered.y,"vision":1}
	battle.visibility.update(battle.units+[scout],battle.player_owner)
	hero.ax=visible.x;hero.ay=visible.y;battle.commands.world._place_unit(hero)
	battle.visibility.update(battle.units,battle.player_owner)
	assert(battle.commands.session._save_game())
	var saved: Dictionary=root.get_node("Game").load_save()
	# A fresh entry world has never seen the saved army's distant position.
	hero.ax=home.x;hero.ay=home.y;battle.commands.world._place_unit(hero)
	battle.visibility.setup(Vector2(battle.map_data.terrainW,battle.map_data.terrainH))
	battle.visibility.update(battle.units,battle.player_owner)
	battle.view.fog_sprite._process(0)
	assert(mask_alpha(visible)==1.0)
	battle.cam.position=visible;battle.view.clamp_camera()
	for child in battle.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			child.update_visible(Rect2(visible-Vector2(900,700),Vector2(1800,1400)))
			assert(child.loaded_bytes<=child.resident_limit())
	await capture("before-load")
	var previous: RefCounted=battle.visibility
	paused=true
	assert(battle.saver.apply_snapshot(saved))
	assert(not is_same(previous,battle.visibility) and is_same(battle.view.fog_sprite.visibility,battle.visibility))
	battle.view.fog_sprite._process(0)
	assert(is_zero_approx(mask_alpha(visible)),"loaded army must clear the real rendered mask")
	assert(is_equal_approx(mask_alpha(remembered),165.0/255.0),"explored fog must remain translucent")
	assert(mask_alpha(unknown)==1.0,"unexplored terrain must remain opaque")
	await capture("after-load")
	paused=false
	print("RESTORED FOG PASS live model identity / paused load / visible-explored-unknown alpha / terrain headroom")

func label(stage: Node2D, text: String, point: Vector2) -> void:
	var node:=Label.new();node.text=text;node.position=point
	node.add_theme_font_size_override("font_size",18);stage.add_child(node)

func direction_poses() -> void:
	battle.cam.enabled=false;battle.cam=null;battle.view.cam=null
	var stage:=Node2D.new();root.add_child(stage)
	var names:= ["E","SE","S","SW","W","NW","N","NE"]
	for i in range(8):label(stage,names[i],Vector2(i*160+60,0))
	for row in range(6):
		var kind: int=[29,31,33,35,32,45][row]
		var regions: Dictionary={}
		for direction in range(8):
			assert(battle.commands.world._spawn_unit(kind,battle.player_owner,800,2000,true))
			var unit: Dictionary=battle.units.back()
			unit.moved=true;unit.state="attack";unit.dir=direction;unit.move_facing=direction;unit.walk_tick=0
			var pose: Dictionary=battle.view.mobile_pose(unit)
			assert(pose.clip=="turn" and int(pose.direction)==(direction+2)%8)
			battle.view.update_visual(unit)
			assert(unit.clips.turn[(direction+2)%8].any(func(f):return int(f)==int(battle.view.unit_nodes(unit).frame)), "kind=%d screen=%d frame=%d pose=%s"%[kind,direction,int(battle.view.unit_nodes(unit).frame),str(pose)])
			assert(not unit.clips.walk[(direction+2)%8].any(func(f):return int(f)==int(battle.view.unit_nodes(unit).frame)),"marching generals must never use their attack row")
			var nodes: Dictionary=battle.view.unit_nodes(unit)
			var key:=str(nodes.skin.texture.get_instance_id())+str(nodes.skin.region_rect)
			regions[key]=true
			nodes.spr.reparent(stage)
			nodes.spr.scale*=2.5
			nodes.spr.position=Vector2(direction*160+80-float(unit.w)*1.25,row*170+160-float(unit.h)*2.5)
			actors.append(unit)
		assert(regions.size()==8,"each screen heading must sample its own sprite region")
		label(stage,"Type %d - locomotion"%kind,Vector2(0,row*170+25))
	for child in battle.view.get_children():
		if child is CanvasLayer:child.hide()
	battle.view.hide()
	for phase in range(4):
		for unit in actors:
			unit.walk_tick=phase*2;battle.view.update_visual(unit)
		await capture("directions-%d"%phase)
	var unit: Dictionary=actors[8]
	unit.moved=false;unit.action_phase=2
	assert(battle.view.mobile_pose(unit).clip=="walk","standing attacks retain the combat action row")
	print("SPRITE DIRECTION PASS six types x8 screen headings / distinct regions / gait only while moving / standing attack retained")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="):output=arg.substr(16)
	if output!="":
		DirAccess.make_dir_recursive_absolute(output)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1280,1080)
	root.get_node("Game").current_map="chibil3"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true;battle.ai=null
	await process_frame;await process_frame
	battle.view.update_hud_text();battle.view.update_panel()
	await restored_mask()
	await direction_poses()
	battle.free()
	quit()
