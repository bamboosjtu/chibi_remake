extends Node
## One SceneTree writer. Each modal owns a lease, never a previous global bool.
var _leases: Dictionary = {}
var _next := 1

func acquire(owner: Node, reason: String) -> int:
	if not is_inside_tree() or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.get_tree() != get_tree():
		push_error("A pause lease needs a live owner in the same SceneTree"); return 0
	var token := _next; _next += 1
	_leases[token] = {"owner":weakref(owner), "reason":reason}
	owner.connect("tree_exiting",release.bind(token), CONNECT_ONE_SHOT)
	_sync()
	return token

func release(token: int) -> void:
	if not _leases.has(token): return
	var owner = _leases[token].owner.get_ref()
	if is_instance_valid(owner) and owner.is_connected("tree_exiting",release.bind(token)):
		owner.disconnect("tree_exiting",release.bind(token))
	_leases.erase(token)
	_sync()

func is_top(token: int) -> bool:
	return token > 0 and _leases.has(token) and token == _leases.keys().back()

func count() -> int:
	return _leases.size()

func _sync() -> void:
	if is_inside_tree(): get_tree().paused = not _leases.is_empty()

func _exit_tree() -> void:
	for token in _leases.keys(): release(token)
