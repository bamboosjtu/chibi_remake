extends RefCounted
const Grades = preload("res://simulation/definitions/officer_grades.gd")
static var data: Dictionary = Grades.data
static func award(officer: Dictionary, amount: int) -> bool:
	if officer.is_empty() or amount<0:return false
	var level:=clampi(int(officer.get("level",0)),0,int(data.levelCap))
	officer.exp=int(officer.get("exp",0))+amount
	var promoted: bool=level<int(data.levelCap) and int(officer.exp)>=int(data.thresholds[level])
	if promoted:
		officer.exp-=int(data.thresholds[level]);level+=1
	officer.level=level
	return promoted


static func cell(officer: Dictionary) -> Dictionary:
	return Grades.cell(officer)
static func reward(unit_id: int) -> Dictionary:
	return Grades.reward(unit_id)
static func progress_text(officer: Dictionary) -> String:
	return Grades.progress_text(officer)
