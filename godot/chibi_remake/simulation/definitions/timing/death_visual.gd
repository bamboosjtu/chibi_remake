extends RefCounted
## Read-only death sampling shared by simulation completion and restored views.
static func frames(unit: Dictionary) -> Array:
	var clips = unit.get("clips",{})
	var directions = clips.get("die",[]) if clips is Dictionary else []
	if not directions is Array or directions.is_empty(): return []
	var result = directions[(int(unit.get("dir",0)) & 7) % directions.size()]
	return result if result is Array else []
static func frame(unit: Dictionary, elapsed: float) -> int:
	var step := int(elapsed / 0.08)
	var sequence := frames(unit)
	if not sequence.is_empty(): return int(sequence[step]) if step < sequence.size() else -1
	var count := int(unit.get("count",0))
	var span := maxi(1,count / maxi(1,int(unit.get("grid",8))))
	var result := maxi(0,count-mini(8,span*maxi(1,int(unit.get("grid",8))))) + mini(7,step)
	return result if result < count else -1
static func alpha(unit: Dictionary, elapsed: float) -> float:
	return maxf(0.0,1.0-elapsed*0.55) if frames(unit).is_empty() else 1.0
