extends RefCounted
## The only JSON rule reader. Called before constructing any battle services.
const Contract = preload("res://simulation/definitions/contracts/rule_contract.gd")
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
static var _attempted := false
static var _errors: Array = []
static var read_count := 0

static func initialize() -> Array:
	if _attempted: return _errors.duplicate()
	_attempted = true
	var report := read_bundle("res://data/db")
	_errors = report.errors
	if _errors.is_empty(): _errors = Catalog.install(report.documents)
	return _errors.duplicate()

static func read_bundle(directory: String) -> Dictionary:
	var documents := {}; var errors := []
	for name in Contract.FILES:
		var path := directory.path_join(name)
		read_count += 1
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			errors.append(path + ": cannot read (error %d)" % FileAccess.get_open_error())
			continue
		var parser := JSON.new()
		var error := parser.parse(file.get_as_text().trim_prefix("\ufeff"))
		file.close()
		if error != OK:
			errors.append(path + ": JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		elif not Contract.valid(name, parser.data): errors.append(path + ": invalid required gameplay fields")
		else: documents[name] = parser.data
	if errors.is_empty(): errors = Contract.errors(documents)
	# Failed bundles cannot be consumed accidentally or published partially.
	return {"documents": documents if errors.is_empty() else {}, "errors": errors}
