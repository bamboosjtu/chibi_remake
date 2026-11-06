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
	root.add_child(b);b.set_process(false);b.cli_mode=true
	await process_frame
	b.view.event_view.restore_history()
	var menu=b.view.battle_menu
	menu.open()
	menu.buttons[3].emit_signal("pressed")
	assert(paused and menu.is_open and menu.settings_panel.visible and not menu.panel.visible)
	for speed in range(4):
		menu.speed_buttons[speed].emit_signal("pressed")
		assert(b.clock.speed_index==speed and "当前" in menu.speed_buttons[speed].text)
		assert(paused,"changing speed cannot resume battle behind settings")
	var key:=InputEventKey.new()
	key.keycode=KEY_ESCAPE;key.pressed=true
	root.push_input(key,true)
	assert(menu.is_open and paused and not menu.settings_panel.visible and menu.panel.visible,"escape returns to system menu")
	# 存档走拾取框：选中空槽并确认，然后再从读取框选中同一条记录。
	menu.save_game()
	var picker=menu.slots_dialog
	assert(picker.overlay.visible and picker.selected_slot>=1,"save picker opens on a free slot")
	var saved_slot: int=picker.selected_slot
	picker._confirm()
	assert(menu.status.text.begins_with("保存成功"),menu.status.text)
	b.commands.world.set_sim_speed(0)
	menu.load_game()
	var loader=menu.slots_dialog
	var index: int=-1
	for i in range(loader.entries.size()):
		if int(loader.entries[i].slot)==saved_slot:index=i
	assert(loader.overlay.visible and index>=0,"load picker lists the saved slot")
	loader.records.select(index);loader._selected(index);loader._confirm()
	assert(not paused and b.clock.speed_index==3)
	assert(menu.buttons[5].text=="结束战役")
	print("CLOCK UI PASS settings / four speeds / escape / pause / save-load / end-campaign entry")
	b.free();done=true;quit()
