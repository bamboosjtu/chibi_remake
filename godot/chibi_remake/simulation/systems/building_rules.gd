extends RefCounted
## Confirmed building research. Map geometry and historical save snapshots stay intact.

static func apply_definitions(map_data: Dictionary) -> void:
	var file := FileAccess.open("res://data/db/buildings.json", FileAccess.READ)
	if file == null: return
	var definitions: Dictionary = JSON.parse_string(file.get_as_text()).get("units", {})
	for uid in definitions:
		var definition: Dictionary = definitions[uid]
		if not map_data.units.has(uid): map_data.units[uid] = definition.duplicate(true)
		map_data.units[uid].costs = definition.costs.duplicate()
		map_data.units[uid].costStone = definition.costStone
		if definition.has("constructionFrames"):
			map_data.units[uid].constructionFrames = definition.constructionFrames.duplicate()

static func construction_frame(hp: float, maxhp: float, meta: Dictionary, count: int) -> int:
	var ratio := clampf(hp / maxf(1.0,maxhp),0.0,1.0)
	var stage := 3 if ratio>=1.0 else (2 if ratio>=2.0/3.0 else (1 if ratio>=1.0/3.0 else 0))
	var frames: Array = meta.get("constructionFrames", [])
	if frames.size()==4:
		# Type 1 currently has eight HD frames; its two absent site frames use
		# the last available incomplete pose, never another building's atlas.
		if int(frames[stage])>=count: return maxi(0,count-1-stage)
		return clampi(int(frames[stage]),0,count-1)
	# Per-type offsets beyond HQ remain unverified. Quantize by the confirmed
	# thirds instead of cycling through damage/storage frames every few HP.
	return clampi(int(ceil(float(3-stage)*float(count-1)/3.0)),0,count-1)
