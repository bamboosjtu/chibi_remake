extends RefCounted
## Synchronous notifications; the scene decides whether a presentation exists.
signal visual_requested(action: String, arguments: Array)
signal sound_requested(action: String, arguments: Array)

func visual(action: String, arguments: Array = []) -> void:
	visual_requested.emit(action, arguments)

func sound(action: String, arguments: Array = []) -> void:
	sound_requested.emit(action, arguments)


signal duel_requested(outcome: String, onm: String, enm: String, ticket: int)
var _duels: Dictionary = {}
var _next_ticket := 0
func reserve_duel(record: Dictionary) -> int:
	_next_ticket += 1
	_duels[_next_ticket] = record.duplicate(true)
	return _next_ticket
func take_duel(ticket: int) -> Dictionary:
	var record: Dictionary = _duels.get(ticket,{})
	_duels.erase(ticket)
	return record
func duel(outcome: String, onm: String, enm: String, ticket: int) -> bool:
	if duel_requested.get_connections().is_empty(): return false
	duel_requested.emit(outcome,onm,enm,ticket)
	return true
func invalidate() -> void:
	_duels.clear()
