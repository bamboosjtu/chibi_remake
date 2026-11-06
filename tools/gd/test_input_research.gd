extends SceneTree
## Focused integration checks for the supplied cursor/command research.
const Cursor = preload("res://presentation/hud/software_cursor.gd")
const Metrics = preload("res://presentation/hud/hud_metrics.gd")
var battle: Node2D
var done := false
var executions := []

func _initialize() -> void:
	create_timer(70).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func record() -> void:
	executions.append(battle.selected.map(func(u):return int(u.uid)))

func charge() -> void:
	battle.gold-=100

func key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new();event.keycode=code;event.pressed=pressed;return event

func mouse(view, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	view._input(event)

func aim(point: Vector2) -> Vector2:
	var view = battle.view
	battle.cam.position=point-(view.battle_rect().get_center()-root.get_visible_rect().size*0.5)/battle.cam.zoom
	battle.cam.force_update_scroll()
	return battle.get_canvas_transform()*point

func run() -> void:
	root.get_node("Game").current_map="chibil1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	await process_frame;await process_frame
	battle.player_commands.set_process(false)
	var view = battle.view
	view.event_view.restore_history()
	var workers: Array=battle.units.filter(func(u):return u.alive and int(u.owner)==battle.player_owner and int(u.unit)==30)
	assert(workers.size()>=2)
	var captain: Dictionary=battle.selected[0]
	battle.selected=[captain];view.update_panel()
	var catalog = view.command_catalog
	assert(catalog.commands.size()==18 and catalog.frames.size()==116)
	assert(catalog.panel("combat").map(func(s):return s.id)==[16130,16131,16132,16133,16135,16134,16136,16142,16137])
	assert(view.command_panel.slots.size()==15 and view.command_panel.mask==255)
	for frame in [98,106,113,122,154,155,162,167,168,169]:
		assert(catalog.icon(frame).get_width()>=190 and catalog.icon(frame).get_height()>=190,"every active command uses painted HD art")
	assert(view._handle_cmd_key(key(KEY_Q)) and battle.commands.cmd_pending_kind()=="move")
	assert(view.art_buttons[0].btn.get_meta("visual_state")==1)
	assert(view._handle_cmd_key(key(KEY_Q,false)))
	assert(view.art_buttons[0].btn.get_meta("visual_state")==0)
	battle.commands._clear_pending()
	var button: Control=view.art_buttons[5].btn
	var point := button.get_global_rect().get_center()
	mouse(view,point,true)
	assert(battle.player_commands.batches.is_empty(),"mouse down must only press")
	var motion := InputEventMouseMotion.new();motion.position=Vector2(200,200);view._input(motion)
	mouse(view,point,false)
	assert(battle.player_commands.batches.is_empty(),"leaving a pressed button cancels even after returning")
	mouse(view,point,true);mouse(view,point,false)
	assert(battle.player_commands.batches.size()==1)
	assert(battle.player_commands.queues[battle.player_owner][0].words[2]==4)
	battle.player_commands.clear()
	assert(view._handle_cmd_key(key(KEY_D)))
	assert(battle.player_commands.queues[battle.player_owner][0].words[2]==4,"same slot key and mouse mode")
	view._handle_cmd_key(key(KEY_D,false));battle.player_commands.clear()
	# Inputs capture their actors, then execute on the frame pump, independently of later selection.
	battle.selected=workers.slice(0,2)
	assert(battle.player_commands.submit(2,record,Vector2(123,456),789)==2)
	assert(executions.is_empty())
	var words: PackedInt64Array=battle.player_commands.queues[battle.player_owner][0].words
	assert(words.size()==8 and words[3]==123 and words[4]==456 and words[5]==789)
	battle.selected=[workers[2]]
	assert(battle.player_commands.pump()==1)
	assert(executions.back()==[workers[0].uid,workers[1].uid] and battle.selected==[workers[2]])
	for mode in [5,10,11]:
		battle.selected=workers.slice(0,2)
		assert(battle.player_commands.submit(mode,record)==1)
		battle.player_commands.pump()
		assert(executions.back()==[workers[0].uid] and battle.selected.size()==2)
	var many := []
	for i in range(65):
		var unit: Dictionary=workers[0].duplicate();unit.uid=900000+i;many.append(unit)
	battle.selected=many
	assert(battle.player_commands.submit(2,record)==64)
	assert(battle.player_commands.queues[battle.player_owner].size()==64)
	assert(battle.player_commands.submit(2,record)==0)
	battle.player_commands.clear();battle.selected=workers;view.update_panel()
	var before_gold: float=battle.gold
	assert(battle.player_commands.submit(16,charge)>0)
	assert(battle.commands._save_game())
	var saved: Dictionary=root.get_node("Game").load_save()
	assert(battle.gold==before_gold-100 and float(saved.resources.gold)==battle.gold,"pending cost and saved resources must be one snapshot")
	print("COMMAND RESEARCH PASS registry / 15 slots / three states / release and cancel / QWE-ASD-ZXC / frame queue / first actor / 64 slots")
	var cursor = Cursor.new();root.add_child(cursor);cursor.set_process(false)
	assert(cursor.data.artMode=="painted-hd")
	if FileAccess.file_exists("res://release_inputs.json"):
		assert(not ResourceLoader.exists("res://art/full/ui/input/cursor-a.png") and not ResourceLoader.exists("res://art/full/ui/input/command-154.png"),"release excludes the retired low-resolution sheets")
	assert(cursor.resolve(null,Vector2.ZERO)=={"bank":"C","row":0})
	var unit: Dictionary=workers[0]
	point=aim(Vector2(unit.ax,unit.ay-float(unit.h)*0.5))
	assert(cursor.resolve(battle,point).row==6,"unit hover")
	battle.commands._cmd_begin("attack")
	assert(cursor.resolve(battle,point).row==2,"friendly attack cursor")
	var enemies: Array=battle.units.filter(func(u):return u.alive and int(u.owner)!=battle.player_owner and int(u.owner)>0)
	assert(not enemies.is_empty())
	unit=enemies[0];point=aim(Vector2(unit.ax,unit.ay-float(unit.h)*0.5))
	battle.visibility.current.fill(1)
	assert(cursor.resolve(battle,point).row==3,"enemy attack cursor")
	var target: Dictionary=battle.decor_targets.filter(func(o):return int(o.phase)==0)[0]
	var draw: Array=battle.remaster_art.runtime_info("resource-decor").frames[0].draw
	point=aim(Vector2(target.ax,target.ay)-Vector2(22,60)+Vector2(draw[0]+draw[2]*0.5,draw[1]+draw[3]*0.5))
	battle.commands._cmd_begin("transport")
	assert(cursor.resolve(battle,point).row==5,"resource sickle")
	battle.selecting=true
	assert(cursor.resolve(battle,point).row==7,"drag overrides resource hover")
	battle.selecting=false;battle.commands._clear_pending()
	battle.cam.position=Vector2(battle.map_data.terrainW,battle.map_data.terrainH)*0.5
	assert(cursor.resolve(battle,Vector2(0,300))=={"bank":"B","row":7})
	cursor.draw_at(battle,Vector2(0,300))
	assert(cursor.sprite.texture.get_width()>=384 and cursor.sprite.region_rect.size.y>=384,"edge arrows use HD vector art")
	battle.cam.position=Metrics.clamp_world_pos(Vector2(-100000,3000),Vector2(battle.map_data.terrainW,battle.map_data.terrainH),view.battle_rect(),root.get_visible_rect().size,battle.cam.zoom)
	assert(cursor.resolve(battle,Vector2(0,300)).bank=="A","edge arrow stops at map clamp")
	cursor.advance(0,{"bank":"A","row":1});cursor.advance(0.159,{"bank":"A","row":1})
	assert(cursor.column==0)
	cursor.advance(0.002,{"bank":"A","row":1});assert(cursor.column==1)
	cursor.advance(0,{"bank":"A","row":2});assert(cursor.column==0)
	assert(Vector2(cursor.data.banks[0].hotspots[1][0],cursor.data.banks[0].hotspots[1][1])==Vector2(26,17))
	assert(Vector2(cursor.data.banks[0].hotspots[8][0],cursor.data.banks[0].hotspots[8][1])==Vector2(1,3))
	cursor.free()
	print("CURSOR RESEARCH PASS A/B/C / hover relations / sickle / drag priority / edge clamp / 160ms animation / hotspots")
	battle.free();done=true;quit()
