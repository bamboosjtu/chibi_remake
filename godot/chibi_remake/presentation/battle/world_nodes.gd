extends RefCounted
## Node staging belongs to presentation; the application only holds a token.
var _ui: RefCounted
func _init(ui: RefCounted) -> void: _ui = ui
func begin() -> Dictionary:
	var token := {"nodes":_ui._nodes_by_uid,"motion":_ui._motion_previous,"gait":_ui._gait_previous}
	_ui._nodes_by_uid = {}; _ui._motion_previous = {}; _ui._gait_previous = {}
	return token
func rollback(token: Dictionary) -> void:
	release(_ui._nodes_by_uid)
	_ui._nodes_by_uid = token.nodes; _ui._motion_previous = token.motion; _ui._gait_previous = token.gait
func commit(token: Dictionary) -> void: release(token.nodes)
func complete(units: Array) -> bool:
	for unit in units:
		var record: Dictionary = _ui._nodes_by_uid.get(int(unit.uid),{})
		for key in ["spr","diamond","hbar"]:
			if record.get(key) == null or not is_instance_valid(record[key]): return false
		if record.spr.texture == null and (record.get("skin") == null or record.skin.texture == null): return false
	return true
func release(records: Dictionary) -> void:
	for record in records.values():
		for key in ["spr","diamond","hbar"]:
			var node = record.get(key)
			if node != null and is_instance_valid(node): node.queue_free()
