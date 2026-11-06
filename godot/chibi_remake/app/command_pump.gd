extends Node
## Resolve the current queue through the stable battle entry after world swaps.
var battle: WeakRef
func _init(owner: Node2D) -> void:
	battle = weakref(owner)
func _process(_delta: float) -> void:
	var owner = battle.get_ref()
	if owner != null and owner.player_commands != null and owner.player_commands.is_processing(): owner.player_commands.pump()
