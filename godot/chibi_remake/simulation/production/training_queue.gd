extends RefCounted
## Decoded training queue restoration.

static func clear_trainings(battle: Object) -> void:
	battle.trainings.clear()

static func append_to_trainings(battle: Object, value: Variant) -> void:
	battle.trainings.append(value)
