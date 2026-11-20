extends RefCounted
## All wall-clock sampling is opt-in and excluded from persistent state.
static func now(enabled: bool) -> int:
	return Time.get_ticks_usec() if enabled else 0
