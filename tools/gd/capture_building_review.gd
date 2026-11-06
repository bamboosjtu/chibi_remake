extends SceneTree
var battle: Node2D
var output := "user://building-review"
var legacy := ""

func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(1))
	run.call_deferred()

func capture(name: String) -> void:
	for u in battle.units:battle.commands.world._update_visual(u)
	battle.view.update_panel();battle.commands.session._view_hud()
	await process_frame;await process_frame
	for child in battle.view.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("terrain_stream.gd"):
			var deadline:=Time.get_ticks_msec()+10000
			while not child._pending.is_empty() and Time.get_ticks_msec()<deadline:await create_timer(0.01,true).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)

func label_at(layer: Node, text: String, pos: Vector2, size:=22) -> void:
	var label:=Label.new();label.text=text;label.position=pos
	label.add_theme_font_size_override("font_size",size);layer.add_child(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
		if arg.begins_with("--legacy-save="):legacy=arg.substr(14)
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
	root.get_node("Game").current_map="chibil1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	if legacy!="":
		var file:=FileAccess.open(legacy,FileAccess.READ)
		assert(battle.saver.apply_snapshot(JSON.parse_string(file.get_as_text())))
	battle.visibility.current.fill(1);battle.visibility.explored.fill(1);battle.visibility.revision+=1
	var gates: Array=battle.units.filter(func(u):return int(u.unit) in [16,17])
	for i in range(gates.size()):
		var gate: Dictionary=gates[i]
		battle.cam.position=Vector2(gate.ax,gate.ay-35)-(battle.view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/battle.cam.zoom
		battle.cam.force_update_scroll()
		await capture("restored-gate-%d-1920"%i)
	for size in [Vector2i(640,480),Vector2i(1280,720)]:
		root.size=size;await process_frame;await process_frame
		var gate: Dictionary=gates[0]
		battle.cam.position=Vector2(gate.ax,gate.ay-35)-(battle.view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/battle.cam.zoom
		battle.cam.force_update_scroll();await capture("restored-gate-0-%d"%size.x)
	# Native rendering of identical poses and team color, before/after metadata.
	root.size=Vector2i(1800,880);await process_frame
	var sheet:=CanvasLayer.new();sheet.layer=90;root.add_child(sheet)
	var background:=ColorRect.new();background.color=Color("302d29");background.size=Vector2(1800,880);sheet.add_child(background)
	label_at(sheet,"原裁切 / 缩放",Vector2(100,25),30);label_at(sheet,"修正后 · 相同单位 / 相同动作",Vector2(980,25),30)
	var row:=0
	for uid in [30,32,36,45]:
		var meta: Dictionary=battle.map_data.units[str(uid)]
		var poses: Array=meta.clips.turn[0].slice(0,3)
		poses.append(meta.clips.turn[2][0]);poses.append(meta.clips.walk[0][0]);poses.append(meta.clips.walk[2][1])
		label_at(sheet,str(meta.name),Vector2(10,95+row*190))
		for side in range(2):
			for col in range(poses.size()):
				var parent:=Sprite2D.new();parent.position=Vector2(20+col*135+side*900,100+row*190);parent.scale=Vector2.ONE*2.5;sheet.add_child(parent)
				var skin: Sprite2D=battle.remaster_art.create_unit_skin(parent,uid,0,Vector2i(meta.w,meta.h))
				if side==0:skin.set_meta("full_frames",battle.remaster_art._full_art._data.atlases[str(uid)].frames)
				battle.remaster_art.update_skin(skin,int(poses[col]),false,-1)
				label_at(sheet,"帧 %d"%int(poses[col]),Vector2(parent.position.x,240+row*190),16)
		row+=1
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join("unit-stature-before-after.png"))==OK)
	print("BUILDING VISUAL PASS saved four gates / three resolutions / HD pose stature comparison")
	battle.free();sheet.free();quit()
