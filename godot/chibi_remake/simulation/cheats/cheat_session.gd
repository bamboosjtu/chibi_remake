extends RefCounted
## Cheat-session switch.

static func set_cheats_enabled(battle: Object, value: Variant) -> void:
	battle.cheats_enabled = value
