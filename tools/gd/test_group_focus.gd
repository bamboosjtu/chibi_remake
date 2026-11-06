extends SceneTree
## Recalling a control group must put its officer first and center the camera.
var done := false

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var hero: Dictionary = {}
	var other: Dictionary = {}
	for u in battle.units:
		if not bool(u.alive) or bool(u.is_building) or int(u.owner) != int(battle.player_owner):
			continue
		if not (u.get("officer", {}) as Dictionary).is_empty():
			if hero.is_empty(): hero = u
		elif other.is_empty():
			other = u
	if hero.is_empty():
		push_error("GROUP FOCUS FAIL: no player officer unit")
		quit(1)
		return

	battle.selected.clear()
	if not other.is_empty(): battle.selected.append(other)
	battle.selected.append(hero)
	battle.commands.military._group_assign(9)
	battle.selected.clear()
	var ok: bool = battle.commands.session.focus_group(9)
	if not ok or battle.selected.is_empty():
		push_error("GROUP FOCUS FAIL: recall returned no selection")
		quit(1)
		return
	if int(battle.selected[0].get("uid", -1)) != int(hero.uid):
		push_error("GROUP FOCUS FAIL: officer is not first in selection")
		quit(1)
		return
	var cam: Camera2D = battle.cam
	if cam == null:
		push_error("GROUP FOCUS FAIL: battle camera is missing")
		quit(1)
		return
	var distance: float = Vector2(float(hero.ax), float(hero.ay)).distance_to(cam.position)
	if distance > 3000.0:
		push_error("GROUP FOCUS FAIL: camera did not follow the officer: %.1f" % distance)
		quit(1)
		return

	# The left-edge HUD button uses the presentation action path instead of the
	# keyboard path; both must select and center through the same service.
	battle.selected.clear()
	battle.view._act_group(9)
	if battle.selected.is_empty() or int(battle.selected[0].get("uid", -1)) != int(hero.uid):
		push_error("GROUP FOCUS FAIL: HUD group action did not select the officer")
		quit(1)
		return
	print("GROUP FOCUS PASS officer-first selection and camera follow (keyboard + HUD)")
	done = true
	quit()
