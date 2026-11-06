extends SceneTree
var battle:Node2D
var output:="user://exploration-review"
var saved:=""
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(1))
	run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
		if arg.begins_with("--legacy-save="):saved=arg.substr(14)
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map="chibil1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	if saved!="":
		var file:=FileAccess.open(saved,FileAccess.READ)
		assert(battle.saver.apply_snapshot(JSON.parse_string(file.get_as_text())))
	var cleared:=0
	for resource in battle.decor_targets:
		if resource.alive:continue
		var cell:Vector2i=battle.commands._unit_cell(resource)
		var id:int=battle.nav._id(cell)
		if int(battle.map_data.waterWalkable[id])!=0 or int(battle.nav.occupancy.get(id,0))>0 or battle.nav.gate_cells.has(id):continue
		assert(not battle.nav.is_solid(cell),"old save's harvested ground must reopen")
		cleared+=1
	print("SAVED RESOURCE FLOOR PASS ",cleared," cleared cells")
	var mini:Control=battle.view.minimap
	assert(mini.map_texture!=null and mini.map_texture.get_width()==384)
	await process_frame;await process_frame
	battle.view.update_panel();battle.commands._view_hud();mini.queue_redraw()
	for unit in battle.units:battle.commands._update_visual(unit)
	# Wait for native terrain uploads, without advancing the player's game.
	for child in battle.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			var deadline:=Time.get_ticks_msec()+10000
			while Time.get_ticks_msec()<deadline:
				if child._pending.is_empty() and not child._wanted.is_empty() and child._wanted.keys().all(func(k):return child.active.has(k)):break
				await create_timer(0.01,true).timeout
	battle.commands._view_hud();mini.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image.save_png(output.path_join("saved-exploration.png"))==OK)
	var base:Image=mini.map_texture.get_image()
	var observed:={"visible":[],"explored":[],"unknown":[]}
	var world_size:=Vector2(battle.map_data.terrainW,battle.map_data.terrainH)
	var rect:Rect2=mini.terrain.get_global_rect()
	for py in range(4,base.get_height()-4,3):
		for px in range(4,base.get_width()-4,3):
			var color:=base.get_pixel(px,py)
			if color.get_luminance()<0.12:continue
			var uv:=Vector2((float(px)+0.5)/base.get_width(),(float(py)+0.5)/base.get_height())
			var world:=uv*world_size
			var index:int=floori(world.y/11)*battle.visibility.width+floori(world.x/22)
			var kind:="visible" if battle.visibility.current[index] else ("explored" if battle.visibility.explored[index] else "unknown")
			var point:=rect.position+uv*rect.size
			var on_marker:=false
			for unit in battle.units:
				if point.distance_to(rect.position+Vector2(unit.ax,unit.ay)/world_size*rect.size)<12:on_marker=true;break
			if on_marker:continue
			var actual:=image.get_pixel(clampi(roundi(point.x),0,image.get_width()-1),clampi(roundi(point.y),0,image.get_height()-1)).get_luminance()
			observed[kind].append(actual)
	var report:={}
	for key in observed:
		var values:Array=observed[key];values.sort()
		assert(not values.is_empty(),"save must include all three minimap visibility states")
		report[key]={"samples":values.size(),"median":values[values.size()/2]}
	var file:=FileAccess.open(output.path_join("minimap-pixels.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("MINIMAP PIXELS ",JSON.stringify(report)," visible=",mini.terrain.visible)
	assert(float(report.visible.median)>0.08)
	assert(float(report.explored.median)>0.02 and float(report.explored.median)<float(report.visible.median))
	assert(float(report.unknown.median)<0.01)
	print("MINIMAP NATIVE PASS visible bright / explored dim terrain / unknown black / actual saved exploration")
	battle.free();quit()
