extends RefCounted
## Small generated menu metadata; full maps are opened only for battle loading.
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
var _reader: Callable
var _attempted := false
var _errors: Array = []
var _levels: Array = []
var _next: Dictionary = {}
var read_count := 0

func _init(reader := Callable()) -> void:
	_reader = reader
	_levels.make_read_only()

func initialize() -> Array:
	if _attempted: return _errors.duplicate()
	_attempted = true; read_count += 1
	var data = _reader.call() if _reader.is_valid() else _read_index()
	if not _valid(data):
		_errors = ["level_index.json: invalid or unavailable level catalog"]
		return _errors.duplicate()
	var owned := Frozen.copy(data)
	var by_id := {}
	for entry in owned.levels: by_id[entry.id] = entry
	for index in range(owned.order.size()-1):
		var current: Dictionary = by_id[owned.order[index]]
		var next: Dictionary = by_id[owned.order[index+1]]
		if current.campaign == next.campaign: _next[current.id] = next
	_levels = owned.levels
	_next.make_read_only()
	return []

func levels() -> Array:
	initialize()
	return _levels

func next_level(map_id: String) -> Dictionary:
	initialize()
	return _next.get(map_id, {})

func contains(map_id: String) -> bool:
	initialize()
	return _levels.any(func(entry): return entry.id == map_id)

static func _read_index():
	var file := FileAccess.open("res://data/db/level_index.json",FileAccess.READ)
	if file == null: return null
	var data = JSON.parse_string(file.get_as_text()); file.close()
	return data

static func _valid(data) -> bool:
	if not data is Dictionary or data.get("schemaVersion") != 1 or not data.get("levels") is Array or data.levels.is_empty(): return false
	if not data.get("order") is Array or data.order.size() != data.levels.size(): return false
	var seen := {}; var ordered := {}; var previous := ""
	for entry in data.levels:
		if not entry is Dictionary: return false
		for key in ["id","map","name","campaign","chapter","title"]:
			if not entry.get(key) is String or entry[key].is_empty(): return false
		if entry.id != entry.map or not entry.id.is_valid_identifier() or seen.has(entry.id) or entry.id <= previous: return false
		var number = entry.get("objects")
		if not (number is int or number is float) or not is_finite(float(number)) or number < 0 or number != floorf(number): return false
		seen[entry.id] = true; previous = entry.id
	for id in data.order:
		if not id is String or not seen.has(id) or ordered.has(id): return false
		ordered[id] = true
	return true
