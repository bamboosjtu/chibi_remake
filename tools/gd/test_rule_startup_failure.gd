extends SceneTree
## Expected exit 1: run only through the isolated rule-startup fault harness.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var catalog = preload("res://simulation/definitions/rule_catalog.gd")
	var loader = preload("res://app/rules/rule_loader.gd")
	assert(not game.startup_valid and loader.read_count == preload("res://simulation/definitions/rule_contract.gd").FILES.size())
	var native_failure := "--rules-native-failure" in OS.get_cmdline_user_args()
	assert(catalog.is_ready() == native_failure)
	assert(preload("res://simulation/native/math_kernel.gd").get_kernel() == null)
	var errors: Array = loader.initialize()
	assert(loader.read_count == preload("res://simulation/definitions/rule_contract.gd").FILES.size() and (errors.is_empty() if native_failure else not errors.is_empty()))
	print("RULE STARTUP FAILURE PASS unpublished invalid bundle / startup refused / no reload or native retry")
	quit(1)
