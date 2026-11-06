extends SceneTree
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(1))
	run.call_deferred()
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,720)
	root.get_node("Game").current_map="chibil1"
	var battle: Node2D=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	var output := "user://input-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame;await process_frame
	battle.view.event_view.restore_history()
	var cursor: CanvasLayer
	for child in root.get_node("Game").get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("software_cursor.gd"):cursor=child
	assert(cursor!=null)
	cursor.set_process(false)
	battle.view.set_process(false)
	var workers: Array=battle.units.filter(func(u):return u.alive and int(u.owner)==battle.player_owner and int(u.unit)==30)
	battle.selected=[battle.units.filter(func(u):return int(u.owner)==battle.player_owner and not u.officer.is_empty())[0]]
	var resources: Array=battle.decor_targets.filter(func(o):return int(o.phase)==0)
	var origin := Vector2(workers[0].ax,workers[0].ay)
	resources.sort_custom(func(a,b):return origin.distance_squared_to(Vector2(a.ax,a.ay))<origin.distance_squared_to(Vector2(b.ax,b.ay)))
	var target: Dictionary=resources[0]
	var draw: Array=battle.remaster_art.runtime_info("resource-decor").frames[0].draw
	var point:=Vector2(target.ax,target.ay)-Vector2(22,60)+Vector2(draw[0]+draw[2]*0.5,draw[1]+draw[3]*0.5)
	battle.cam.zoom=Vector2.ONE*2.5
	battle.cam.position=point-(battle.view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/battle.cam.zoom
	battle.cam.force_update_scroll();battle.commands._view_hud();battle.view.update_panel()
	for i in range(45):await process_frame
	battle.commands._cmd_begin("transport")
	var pointer: Vector2=battle.get_canvas_transform()*point
	await process_frame;await process_frame
	cursor.draw_at(battle,pointer)
	assert(cursor.sprite.visible and cursor.bank=="A" and cursor.row==5,"real software cursor should render resource state")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("resource-cursor.png"))
	battle.commands._clear_pending();battle.commands._feedback("")
	pointer=battle.view.art_buttons[2].btn.get_global_rect().get_center()
	await process_frame;await process_frame
	battle.view.draw_hover_at(pointer);cursor.draw_at(battle,pointer)
	assert(battle.view.art_buttons[2].btn.get_meta("visual_state")==2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("command-hover.png"))
	var hq: Dictionary=battle.units.filter(func(u):return u.alive and u.owner==battle.player_owner and int(u.unit)==0)[0]
	var focus:=Vector2(hq.ax,hq.ay-20)
	battle.cam.position=focus-(battle.view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/battle.cam.zoom
	battle.cam.force_update_scroll()
	for worker in workers:worker.group_officer=-1
	battle.selected=workers.slice(0,2);battle.view.update_panel();battle.commands._view_hud()
	for unit in battle.units:battle.commands._update_visual(unit)
	battle.view.draw_hover_at(Vector2(600,600));cursor.draw_at(battle,Vector2(600,600))
	for i in range(30):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("independent-workers-hd.png"))
	assert(battle.view._panel_specs().map(func(s):return s.cmd)==["move","form","join","board"])
	battle.selected=[hq];battle.view.update_panel()
	for unit in battle.units:battle.commands._update_visual(unit)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("building-selection.png"))
	var menu=battle.view.battle_menu
	menu.open();menu.save_game()
	var dialog=menu.slots_dialog
	dialog.records.select(0);dialog._selected(0);dialog.name_field.text="初建营地"
	dialog._confirm()
	menu.save_game();dialog.records.select(1);dialog._selected(1);dialog.name_field.text="粮田扩张"
	dialog._confirm();menu.load_game()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_visible_rect().encloses(dialog.panel.get_global_rect()),"initial save picker must fit before any resize")
	assert(dialog.panel.get_global_rect().encloses(dialog.confirm_button.get_global_rect()),"confirmation remains visible below the scrollable list")
	root.get_texture().get_image().save_png(output.path_join("multiple-saves.png"))
	assert(dialog.overlay.visible and dialog.records.item_count>=20)
	for dimensions in [Vector2i(640,480),Vector2i(1560,1440),Vector2i(1920,1080)]:
		root.size=dimensions;await process_frame;await process_frame
		var rect: Rect2=dialog.panel.get_global_rect()
		assert(root.get_visible_rect().encloses(rect),"save dialog must fit the viewport")
	menu.close()
	print("HD UI CAPTURE PASS independent worker four commands / footprint-sized building / complete portrait / multiple saves / three viewport sizes")
	print("INPUT CAPTURE PASS software resource cursor / original button hover / bottom hotkey prompt")
	battle.free();quit()
