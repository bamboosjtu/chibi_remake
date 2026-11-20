extends RefCounted
## Unknown presentation requests never alter simulation state.
var _strict: bool
var _unknown: Dictionary = {}
var _reported := false

func _init(strict: bool = OS.is_debug_build()) -> void:
	_strict = strict

func unknown(kind: String, action: String) -> void:
	var key := kind + ":" + action
	_unknown[key] = int(_unknown.get(key, 0)) + 1
	if _strict:
		preload("res://composition_contract.gd").abort_if_broken(kind + " event", [{"method": action}])
		return
	if int(_unknown[key]) == 1:
		push_warning("Unhandled presentation event dropped: " + key)

func snapshot() -> Dictionary:
	return _unknown.duplicate()

func report() -> void:
	if _strict or _reported or _unknown.is_empty(): return
	_reported = true
	push_warning("Unhandled presentation events at battle end: " + JSON.stringify(_unknown))
