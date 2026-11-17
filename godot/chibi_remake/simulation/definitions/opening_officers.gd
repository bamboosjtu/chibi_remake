extends RefCounted
## Each world owns its mutable officer progression, copied once at creation.
static func pool(sides: Array) -> Array:
	var data := preload("res://simulation/definitions/rule_catalog.gd").get_catalog("officers.json")
	var result: Array=[[],[],[],[]];var by_id := {}
	for block in data.blocks:
		var officers: Array = block.officers.duplicate(true)
		result[int(block.faction)-1] = officers
		for officer in officers: by_id[int(officer.index)+1]=officer
	for side in sides:
		var roster: Array=side.get("roster",[]);var ranks: Array=side.get("ranks",[])
		for i in range(mini(roster.size(),ranks.size())):
			if by_id.has(int(roster[i])) and int(ranks[i])>0: by_id[int(roster[i])].level=clampi(int(ranks[i])-1,0,9)
	for id in by_id:
		if id<=33 and int(by_id[id].get("level",0))==0: by_id[id].level=5
	return result
