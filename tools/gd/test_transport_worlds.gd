extends "test_transports.gd"
## Independent map coverage; all original coastline/boarding/snapshot assertions remain.
func case_timeout() -> float: return 100.0
func run() -> void:
	game = root.get_node("Game")
	for map_id in MAPS: check_world(map_id)
	print("TRANSPORT WORLDS PASS 11 naval maps / actual coastline / board / loaded snapshot / unique landing")
	done=true;b.queue_free();await process_frame;quit(0)
