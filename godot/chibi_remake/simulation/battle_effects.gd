extends RefCounted
## Synchronous notifications; the scene decides whether a presentation exists.
signal visual_requested(action: String, arguments: Array)
signal sound_requested(action: String, arguments: Array)
var simulating := false
const COALESCED_VISUALS := {"place_unit":true,"fade_unit":true,"hide_unit":true,"update_visual":true,"set_frame":true}

func visual(action: String, arguments: Array = []) -> void:
	if simulating and COALESCED_VISUALS.has(action):return
	visual_requested.emit(action, arguments)

func feedback(message: String) -> void:
	visual("feedback", [message])

func sound(action: String, arguments: Array = []) -> void:
	sound_requested.emit(action, arguments)


signal duel_requested(outcome: String, onm: String, enm: String)

func close() -> void:
	for event: Signal in [visual_requested, sound_requested, duel_requested]:
		for connection in event.get_connections():
			event.disconnect(connection.callable)
