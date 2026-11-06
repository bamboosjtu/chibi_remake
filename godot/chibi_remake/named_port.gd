extends RefCounted
## Weak provider lifetime guard shared by every explicit command/dependency port.
func _require(reference: WeakRef, provider: String) -> Object:
	var target: Object = reference.get_ref() if reference != null else null
	if target == null:
		preload("res://composition_contract.gd").abort_if_broken("expired port", [], [{"provider":provider,"method":"provider lifetime"}])
	return target
