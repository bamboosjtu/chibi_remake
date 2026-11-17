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
	var owned := documents.duplicate(true)
	# JSON numbers are floats; role/row membership uses integer Variant equality.
	for name in ["tech.json", "unit_roles.json", "balance.json"]: _integer_ids(owned[name])
	Frozen.freeze(owned)
	_documents = owned
	return []

static func _integer_ids(value) -> void:
	if value is Dictionary:
		for key in value:
			if value[key] is float and is_finite(value[key]) and value[key] == floorf(value[key]): value[key] = int(value[key])
			else: _integer_ids(value[key])
	elif value is Array:
		for index in range(value.size()):
			if value[index] is float and is_finite(value[index]) and value[index] == floorf(value[index]): value[index] = int(value[index])
			else: _integer_ids(value[index])

static func get_catalog(name: String) -> Dictionary:
	assert(is_ready(), "Rules must be loaded before creating a battle")
	return _documents[name]
