extends RefCounted
## Battle frame policy: view frame, fixed-step simulation pump and HUD cadence.
## Kept out of App so scene_controller only orchestrates lifecycle and saves.

const Config = preload("res://simulation/definitions/battle_config.gd")

var scene: Object
var node: Node2D
var owner: Object
var _dep_battle_simulation: Object

func _init(services: Object, surface: Node2D, controller: Object) -> void:
	scene = services
	node = surface
	owner = controller

func bind_dependencies(scene_root: Object) -> void:
	_dep_battle_simulation = scene_root.world.battle_simulation

func _process(delta: float) -> void:
	var battle = node.state
	if not battle.map_data.has("terrainW"):
		return
	var view_begin := Time.get_ticks_usec()
	_view_frame(delta)
	owner.view_microseconds += Time.get_ticks_usec() - view_begin
	owner.set_sim_acc(battle.sim_acc + delta if battle.game_end == 0 else 0.0)
	var steps := 0
	var period: float = node.world.clock.period()
	var target_tick := ceili(battle.simtest_seconds * Config.SIM_HZ) if battle.simtest_seconds > 0.0 else -1
	while battle.game_end == 0 and not node.get_tree().paused and battle.sim_acc + 0.000000001 >= period and steps < Config.SIM_MAX_CATCHUP and (target_tick < 0 or battle.sim_tick < target_tick):
		owner.set_sim_acc(maxf(0.0, battle.sim_acc - period))
		steps += 1
		_dep_battle_simulation.advance(Config.SIM_DT)
	if target_tick >= 0 and (battle.sim_tick >= target_tick or battle.game_end != 0):
		owner._finish_simtest()
		return
	scene.hud_acc += delta
	if scene.hud_acc >= 1.0 / Config.HUD_HZ:
		scene.hud_acc = 0.0
		if scene.feedback_text != "" and (scene.feedback_until == 0 or scene.feedback_observed != scene.feedback_text):
			scene.feedback_observed = scene.feedback_text
			scene.feedback_until = Time.get_ticks_msec() + 2500
		elif scene.feedback_text != "" and Time.get_ticks_msec() > scene.feedback_until:
			scene.feedback_text = ""
		var hud_begin := Time.get_ticks_usec()
		_view_hud()
		owner.hud_microseconds += Time.get_ticks_usec() - hud_begin
	if scene.view != null:
		scene.view.flush_visuals(true)
		var interpolate_begin := Time.get_ticks_usec()
		scene.view.interpolate_motion(clampf(battle.sim_acc / period, 0.0, 1.0))
		owner.interpolation_microseconds += Time.get_ticks_usec() - interpolate_begin

func _view_frame(delta: float) -> void:
	_edge_scroll(delta)
	_update_hover()

func _view_hud() -> void:
	if scene.view == null:
		return
	scene.view.update_hud_text()
	scene.view.update_panel()

func _edge_scroll(delta: float) -> void:
	if scene.view != null:
		scene.view.edge_scroll(delta)

func _update_hover() -> void:
	if scene.view != null:
		scene.view.update_hover()

func _setup_camera() -> void:
	if scene.view == null:
		return
	scene.view.setup_camera()
	scene.cam = scene.view.cam
