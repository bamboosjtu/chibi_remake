extends SceneTree
## The wrapper expects exit 1, without a script error or initialized gameplay.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(not root.get_node("Game").startup_valid)
	print("APP STARTUP FAILURE PASS invalid application configuration refused")
	quit(1)
