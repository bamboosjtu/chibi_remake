extends RefCounted
## App-owned scene state. Keeps save orchestration out of presentation state.
var saver: RefCounted = null
var ready_to_save := false
