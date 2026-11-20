extends RefCounted
## Shared assertion state for the development and exported acceptance checks.
var host: Node2D
var _suite: WeakRef
var suite: RefCounted:
	get: return _suite.get_ref() if _suite != null else null

func _init(battle: Node2D, runner: RefCounted) -> void:
	host = battle
	_suite = weakref(runner) if runner != null else null
