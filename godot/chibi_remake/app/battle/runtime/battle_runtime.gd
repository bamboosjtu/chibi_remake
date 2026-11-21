extends RefCounted
## App-side scene lifecycle: smoke evidence, fatal screen, save application and
## close-request save. Input, frame and presentation state live elsewhere.
const State = preload("res://simulation/state/battle_state.gd")
const SceneServices = preload("res://app/battle/runtime/battle_scene_state.gd")

var scene: SceneServices
var node: Node2D
var screenshotter: Callable

func _init(services: SceneServices, surface: Node2D, shot: Callable) -> void:
	scene = services
	node = surface
	screenshotter = shot

func _write_smoke(ok: bool, why: String) -> void:
	var file := FileAccess.open("user://smoke.json", FileAccess.WRITE)
	if file == null:
		push_warning("smoke: 无法写入 user://smoke.json")
		return
	var battle: State = node.state
	file.store_string(JSON.stringify({
		"ok": ok, "why": why, "map": battle.map_id,
		"units": battle.units.size(), "mission": battle.scenario_mission,
		"player": battle.player_owner, "scenarioSource": battle.scenario_source,
		"officerPolicy": battle.officer_policy,
	}))
	file.close()

func _fatal(msg: String) -> void:
	push_error(msg)
	_write_smoke(false, msg)
	var layer := CanvasLayer.new()
	node.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.02, 0.02, 1.0)
	bg.size = Vector2(1600, 900)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var label := Label.new()
	label.position = Vector2(60, 60)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	label.text = "加载失败\n\n" + msg
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	scene.cam = Camera2D.new()
	node.add_child(scene.cam)
	scene.cam.make_current()
	if "--screenshot" in OS.get_cmdline_user_args():
		await node.get_tree().create_timer(0.6).timeout
		if screenshotter.is_valid(): await screenshotter.call(node)
		node.get_tree().quit()
	elif "--smoketest" in OS.get_cmdline_user_args():
		node.get_tree().quit()

func _apply_save() -> bool:
	return scene.saver.apply()

func _save_extra() -> Dictionary:
	return scene.saver.save_extra()

func _schedule_failed_load_return() -> void:
	scene.ready_to_save = false
	node.set_process(false)
	node.set_process_unhandled_input(false)
	if node.is_inside_tree():
		Game.return_to_menu.call_deferred()

func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if scene.ready_to_save and scene.saver != null:
		if scene.view != null and scene.view.battle_menu != null:
			await scene.view.battle_menu.open()
			scene.view.battle_menu.quit_game()
			return
		if not await node.session_actions.wait_command_boundary():
			return
		if not node.session_actions.save_game():
			node.world.effects.feedback("保存失败，未退出，请重试")
			return
	node.get_tree().quit()
