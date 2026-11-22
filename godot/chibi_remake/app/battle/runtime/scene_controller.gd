extends Object
const UnitMotion = preload("res://simulation/movement/unit_motion.gd")
const WorldInputs = preload("res://simulation/world/world_inputs.gd")
const CombatState = preload("res://simulation/combat/combat_state.gd")
var view_microseconds := 0
var hud_microseconds := 0
var interpolation_microseconds := 0
## scene controller: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State:
	get: return node.state
var _dep_battle_simulation: Object
var _dep_cheat_controller: Object
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_harvest_orders: Object
var _dep_selection: Object
var _dep_world_orders: Object
const SceneServices = preload("res://app/battle/runtime/battle_scene_state.gd")
const RuntimeService = preload("res://app/battle/runtime/battle_runtime.gd")
var scene: SceneServices
var node: Node2D
var screenshotter: Callable
var runtime: Object
var input_controller: Object
var frame_controller: Object

func _init(services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface
	runtime = RuntimeService.new(services, surface, Callable(self, "_screenshot"))







func _unhandled_input(event: InputEvent) -> void:
	if input_controller != null: input_controller._unhandled_input(event)

func _process(delta: float) -> void:
	if frame_controller != null: frame_controller._process(delta)

func _view_hud() -> void:
	if frame_controller != null: frame_controller._view_hud()

func _setup_camera() -> void:
	if frame_controller != null: frame_controller._setup_camera()

func _screenshot() -> void:
	if input_controller != null: await input_controller._screenshot()
	else: printerr("screenshot hook is not configured")

func set_sim_acc(value: float) -> void:
	WorldInputs.set_sim_acc(node.state, value)

func _finish_simtest() -> void:
	var battle = node.state
	print("SIMTEST: %.1fs tick=%d digest=%d" % [battle.simtest_seconds, battle.sim_tick, _dep_battle_simulation._state_digest()])
	print("SIMULATION DIGESTS: ", JSON.stringify(preload("res://simulation/diagnostics/state_digest.gd").sections(node, node.get_node("/root/Game"))))
	print("SIMULATION FULL DIGEST: ", Game.save_checksum(scene.saver.continuation_snapshot(Game)))
	node.get_tree().quit()

func _write_smoke(ok: bool, why: String) -> void: runtime._write_smoke(ok, why)
func _fatal(msg: String) -> void: runtime._fatal(msg)
func _apply_save() -> bool: return runtime._apply_save()
func _save_extra() -> Dictionary: return runtime._save_extra()
func _schedule_failed_load_return() -> void: runtime._schedule_failed_load_return()
func _notification(what: int) -> void: runtime._notification(what)

func _build_terrain() -> void:
	# ARCH-013：地形是纯 Sprite2D 工厂，归 battle_view.gd
	if scene.view != null:
		scene.view.build_terrain()

func _build_ui() -> void:
	# ARCH-013：HUD 全部交给 battle_view.gd（同名转发，调用点不变）
	if scene.view == null:
		return
	scene.view.build_ui()
	_build_marquee()

func _build_marquee() -> void:
	if scene.view != null:
		scene.view.build_marquee()

func _demo() -> void:
	await node.get_tree().create_timer(0.4).timeout
	var n := 0
	for u in battle.units:
		if u.owner == battle.player_owner and not u.is_building and u.alive:
			var e = _dep_combat._nearest_enemy(u, 99999.0)
			if not e.is_empty():
				n += int(_dep_world_orders._attack_units([u], e, battle.player_owner))
	print("DEMO: ordered %d units to attack" % n)
	var t := 0.0
	while t < 60.0:
		await node.get_tree().create_timer(0.5).timeout
		t += 0.5
		var pa := 0
		var ea := 0
		var ph := 0.0
		var eh := 0.0
		for u in battle.units:
			if u.is_building or not u.alive or u.die_t >= 0.0:
				continue
			if u.owner == battle.player_owner:
				pa += 1
				ph += u.hp
			elif u.owner != 0:
				ea += 1
				eh += u.hp
		if int(t * 2.0) % 10 == 0:
			print("DEMO t=%.1f  我军 alive=%d hp=%.0f | 敌军 alive=%d hp=%.0f" % [t, pa, ph, ea, eh])
		# 原版判定还要看建筑与资源，所以这里必须用 game_end 而不是"某一方单位清零"
		if t > 2.0 and battle.game_end != 0:
			break
	print("DEMO DONE t=%.1f" % t)
	node.get_tree().quit()

func bind_dependencies(scene_root: Object) -> void:
	_dep_battle_simulation = scene_root.world.battle_simulation
	_dep_cheat_controller = scene_root.cheat_controller
	_dep_combat = scene_root.world.combat
	_dep_command_groups = scene_root.world.command_groups
	_dep_harvest_orders = scene_root.world.harvest_orders
	_dep_selection = scene_root.world.selection
	_dep_world_orders = scene_root.world.world_orders
	if input_controller != null: input_controller.bind_dependencies(scene_root)
	if frame_controller != null: frame_controller.bind_dependencies(scene_root)
