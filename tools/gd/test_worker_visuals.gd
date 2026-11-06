extends SceneTree
## Inspect the sampled pixels as well as animation indices: a valid frame index
## can still contain half of the neighbouring cargo pose in an uneven atlas.
var battle: Node2D
var images := {}
var output := ""
var stage: Node2D
var actors: Array = []

func _initialize() -> void:
	run.call_deferred()

func single_pose(unit: Dictionary) -> void:
	var skin: Sprite2D = battle.view.unit_nodes(unit).skin
	assert(skin.visible)
	var key := skin.texture.get_instance_id()
	if not images.has(key):
		var image: Image = skin.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		images[key] = {"width":image.get_width(), "bytes":image.get_data()}
	var pixels: Dictionary = images[key]
	var box := Rect2i(skin.region_rect)
	var previous := -1
	for y in range(box.position.y, box.end.y):
		var count := 0
		for x in range(box.position.x, box.end.x):
			if pixels.bytes[(y * int(pixels.width) + x) * 4 + 3] > 96: count += 1
		if count < 3: continue
		assert(previous < 0 or y-previous <= 6,
			"worker frame %d includes disconnected neighbouring art at row %d" % [int(battle.view.unit_nodes(unit).frame),y])
		previous = y
	assert(previous >= 0, "a living worker must have visible pixels")

func poses(worker: Dictionary, cargo: String, clip: String) -> void:
	worker.carry = 0.0 if cargo == "" else 100.0
	# Empty-handed workers can retain the last delivered resource kind.
	worker.carry_kind = "wood" if cargo == "" else cargo
	worker.moved = true; worker.state = "move"
	for heading in range(8):
		worker.dir = heading; worker.move_facing = heading
		for phase in range(4):
			worker.walk_tick = phase * 2
			var pose: Dictionary = battle.view.mobile_pose(worker)
			assert(pose.clip == clip and int(pose.direction) == (heading+2)%8)
			battle.view.update_visual(worker)
			assert(worker.clips[clip][(heading+2)%8].any(func(f):return int(f)==int(battle.view.unit_nodes(worker).frame)))
			single_pose(worker)
			if cargo == "":
				var skin: Sprite2D = battle.view.unit_nodes(worker).skin
				var size: Vector2 = skin.region_rect.size * skin.scale * battle.view.unit_nodes(worker).spr.scale
				assert(size.y >= 22 and size.y <= 23.1, "empty walking keeps the source body height")

func action_poses(worker: Dictionary) -> void:
	worker.carry = 100.0; worker.carry_kind = "wood"
	for state in ["attack", "repair"]:
		worker.state = state; worker.moved = false
		for heading in range(8):
			worker.dir = heading
			for phase in range(5):
				worker.action_phase = phase
				assert(battle.view.mobile_pose(worker).clip == "walk")
				battle.view.update_visual(worker)
				assert(int(battle.view.unit_nodes(worker).frame)==int(worker.clips.walk[(heading+2)%8][phase]))
				single_pose(worker)
	worker.moved = true; worker.carry = 0
	assert(battle.view.mobile_pose(worker).clip == "turn", "moving to work does not swing the hammer")
	print("WORKER VISUAL PASS eight headings x4 gait phases / empty-wood-stone-gold-food / attack-repair / sampled pixels and stature")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)

func gallery() -> void:
	if output == "": return
	stage = Node2D.new(); root.add_child(stage)
	var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	for row in range(4):
		for heading in range(8):
			assert(battle.commands.world._spawn_unit(30,battle.player_owner,800,2000,true))
			var unit: Dictionary = battle.units.back()
			unit.state="move"; unit.moved=true; unit.dir=heading; unit.move_facing=heading
			unit.carry=0 if row==0 else 100; unit.carry_kind=["wood","wood","stone","food"][row]
			battle.view.update_visual(unit)
			var sprite: Sprite2D = battle.view.unit_nodes(unit).spr
			sprite.reparent(stage); sprite.scale*=3
			sprite.position=Vector2(heading*160+80-float(unit.w)*1.5,row*180+170-float(unit.h)*3)
			actors.append(unit)
			var label := Label.new()
			label.text=names[heading]+" / "+["empty","wood","ore","food"][row]
			label.position=Vector2(heading*160+10,row*180+5);stage.add_child(label)
	for child in battle.view.get_children():
		if child is CanvasLayer: child.hide()
	battle.cam.enabled=false; battle.cam=null; battle.view.cam=null; battle.view.hide()
	for phase in range(4):
		for unit in actors:
			unit.walk_tick=phase*2; battle.view.update_visual(unit)
		await capture("workers-phase-%d"%phase)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output=arg.substr(16)
	if output != "":
		DirAccess.make_dir_recursive_absolute(output)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1280,740)
	root.get_node("Game").current_map="chibil1"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true;battle.ai=null
	await process_frame; await process_frame
	var worker: Dictionary=battle.units.filter(func(u):return int(u.unit)==30 and int(u.owner)==battle.player_owner)[0]
	for cargo in ["","wood","stone","gold","food"]:
		poses(worker,cargo,{"":"turn","wood":"act1","stone":"act2","gold":"act2","food":"act3"}[cargo])
	action_poses(worker)
	await gallery()
	battle.free()
	if stage != null: stage.free()
	quit()
