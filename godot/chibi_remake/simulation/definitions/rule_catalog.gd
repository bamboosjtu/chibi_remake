extends RefCounted
## One immutable, process-wide ruleset. Startup owns publication; worlds only read.
const Contract = preload("res://simulation/definitions/rule_contract.gd")
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
static var _documents: Dictionary = {}

static func is_ready() -> bool:
	return not _documents.is_empty()

static func install(documents: Dictionary) -> Array:
	if is_ready(): return ["Rules are already installed; live replacement is unsupported"]
	var errors := Contract.errors(documents)
	if not errors.is_empty(): return errors
	_documents = Frozen.copy(documents)
	return []

static func get_catalog(name: String) -> Dictionary:
	assert(is_ready(), "Rules must be loaded before creating a battle")
	return _documents[name]
