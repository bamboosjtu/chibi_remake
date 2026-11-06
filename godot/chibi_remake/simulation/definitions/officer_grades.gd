extends RefCounted
static var data: Dictionary = _load()

static func _load() -> Dictionary:
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/officer_progression.json"))
	_freeze(result)
	return result

static func _freeze(value) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()


static func cell(officer: Dictionary) -> Dictionary:
	var category:=clampi(int(officer.get("tier",4)),1,4)
	return data.gradeTable[clampi(int(officer.get("level",0)),0,9)].cells[category-1]

static func reward(unit_id: int) -> Dictionary:
	for entry in data.rewards:
		if int(entry.id)==unit_id:return entry
	return {"killXp":0,"morale":0}

static func progress_text(officer: Dictionary) -> String:
	var level:=clampi(int(officer.get("level",0)),0,9)
	return "%d/—" % int(officer.get("exp",0)) if level==9 else "%d/%d" % [int(officer.get("exp",0)),int(data.thresholds[level])]
