extends RefCounted
## research/meta: exact lowercase character matcher and battle-only hotkeys.
const State = preload("res://simulation/battle_state.gd")
const Services = preload("res://app/battle_scene_state.gd")
const Console = preload("res://presentation/hud/cheat_console.gd")
const CHEAT_ACTIONS := {KEY_F2:"auto", KEY_F3:"demote", KEY_F4:"promote", KEY_F5:"ui",
	KEY_F6:"build", KEY_F7:"invulnerable", KEY_F8:"reveal", KEY_F9:"resources"}
var battle: State:
	get: return node.state
var scene: Services
var node: Node2D
var ports = preload("res://app/battle/ports/cheat_controller_dependencies.gd").new()
var text := ""
var matched := 0
var console: CanvasLayer

func _init(data: State, services: Services, surface: Node2D) -> void:
	scene = services
	node = surface

func handle_cheat_input(event: InputEvent) -> bool:
	if node.get_tree().paused and not scene.cheat_input_open: return false
	if scene.cheat_input_open:
		if event is InputEventKey and event.pressed and not event.echo: _cheat_type(event)
		return true
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return false
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_set_cheat_input(true)
			return true
		KEY_F11:
			ports.screenshot()
			return true
		KEY_P:
			_cheat_camera_enemy()
			return true
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			if battle.cheats_enabled: _cheat_level(-1 if event.keycode == KEY_BRACKETLEFT else 1)
			return battle.cheats_enabled
	if event.keycode >= KEY_F2 and event.keycode <= KEY_F10:
		var message := ports.action(str(CHEAT_ACTIONS.get(event.keycode, "")))
		if message != "": ports.feedback(message)
		if scene.view != null:
			scene.view.update_panel()
			if event.keycode == KEY_F8:
				for unit in battle.units: scene.view.update_visual(unit)
		return true
	return false

func _set_cheat_input(opened: bool) -> void:
	scene.cheat_input_open = opened
	battle.drag_pan = false
	battle.selecting = false
	text = ""
	matched = 0
	if opened:
		if not is_instance_valid(console):
			console = Console.new(Callable(scene.view, "battle_rect") if scene.view != null else Callable())
			node.add_child(console)
		console.update_input(text)
	elif is_instance_valid(console): console.hide()

func _cheat_type(event: InputEventKey) -> void:
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		_set_cheat_input(false)
		return
	if event.keycode == KEY_BACKSPACE:
		text = text.left(maxi(0, text.length()-1))
		matched = 0
	elif event.unicode >= 32 and event.unicode != 127:
		var character := String.chr(event.unicode)
		text = (text + character).right(100)
		# On mismatch the original resets, without retrying the same character.
		matched = matched + 1 if matched < 7 and character == "eternal"[matched] else 0
		if matched == 5:
			battle.cheats_enabled = not battle.cheats_enabled
			ports.feedback("秘籍已开启" if battle.cheats_enabled else "秘籍已关闭")
	if is_instance_valid(console): console.update_input(text)

func _cheat_camera_enemy() -> void:
	if scene.cam == null: return
	for unit in battle.units:
		if not bool(unit.alive) or float(unit.die_t) >= 0 or int(unit.owner) in [0, battle.player_owner]: continue
		if bool(unit.get("attached", false)) or int(unit.get("site_inside_uid", -1)) >= 0: continue
		scene.cam.position = Vector2(unit.ax, unit.ay)
		if scene.view != null: scene.view.clamp_camera()
		return
	ports.feedback("当前战场没有敌军")

func _cheat_level(direction: int) -> void:
	var game := node.get_node("/root/Game")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/startup_briefings.json"))
	var levels: Array = catalog.get("levels", [])
	var target := _cheat_adjacent_level(levels, battle.map_id, direction)
	if target == "":
		ports.feedback("当前战役没有%s关" % ("上一" if direction < 0 else "下一"))
		return
	game.current_map = target
	game.pending_load = false
	game.pending_load_slot = 0
	node.get_tree().paused = false
	node.get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func _cheat_adjacent_level(levels: Array, current: String, direction: int) -> String:
	for i in range(levels.size()):
		if str(levels[i].map) != current: continue
		var next := i + direction
		if next >= 0 and next < levels.size() and str(levels[i].campaign) == str(levels[next].campaign): return str(levels[next].map)
	return ""
