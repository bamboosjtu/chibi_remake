extends RefCounted
static var data: Dictionary:
	get: return preload("res://simulation/definitions/rule_catalog.gd").get_catalog("officer_progression.json")

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
