extends SceneTree
## Every domain command and dependency port must resolve at startup.
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	assert(battle._api_missing.is_empty(), "battle unresolved ports: %s" % str(battle._api_missing))
	var view = battle.view
	assert(view._api_missing.is_empty(), "view unresolved ports: %s" % str(view._api_missing))
	var nav = battle.nav
	assert(nav._api_missing.is_empty(), "nav unresolved ports: %s" % str(nav._api_missing))
	var menu = load("res://menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	assert(menu._api_missing.is_empty(), "menu unresolved ports: %s" % str(menu._api_missing))
	print("REGISTRY PASS battle/view/menu/nav explicit contracts and resolved ports")
	done = true
	quit()
