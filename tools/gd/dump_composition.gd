extends SceneTree
## Reflect real engine method lists, including inherited/static script methods.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var view = load("res://presentation/battle/view/battle_view.gd").new(battle.create_view_context())
	var menu = load("res://menu.tscn").instantiate()
	var reports: Dictionary = preload("res://composition_contract.gd").reports.duplicate(true)
	assert(reports.has_all(["main", "view", "menu", "nav"]))
	for label in reports:
		assert(reports[label].missing.is_empty())
	print("COMPOSITION JSON: " + JSON.stringify(reports))
	print("COMPOSITION PASS four roots / concrete service scripts / required collaborators")
	view.free()
	menu.free()
	battle.free()
	quit()
