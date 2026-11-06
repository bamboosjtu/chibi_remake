extends SceneTree
## Reflect real engine method lists, including inherited/static script methods.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var view = load("res://presentation/battle/battle_view.gd").new(battle)
	var menu = load("res://menu.tscn").instantiate()
	var reports: Dictionary = preload("res://composition_contract.gd").reports.duplicate(true)
	assert(reports.has_all(["main", "view", "menu", "nav"]))
	for label in reports:
		assert(reports[label].conflicts.is_empty() and reports[label].missing.is_empty())
	print("COMPOSITION JSON: " + JSON.stringify(reports))
	print("COMPOSITION PASS engine reflection / all four roots / inherited methods / port contracts")
	view.free()
	menu.free()
	battle.free()
	quit()
