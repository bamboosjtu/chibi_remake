extends RefCounted
## Session-only process options.

static func set_simtest_seconds(battle: Object, value: Variant) -> void:
	battle.simtest_seconds = value

static func set_cli_mode(battle: Object, value: Variant) -> void:
	battle.cli_mode = value
