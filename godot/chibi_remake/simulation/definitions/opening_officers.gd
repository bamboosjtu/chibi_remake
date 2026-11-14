extends RefCounted
## Shared initial officer data for new battles and legacy normalization.
static func pool(sides: Array) -> Array:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/officers.json"))
	var result: Array=[[],[],[],[]];var by_id := {}
	for block in data.blocks:
		result[int(block.faction)-1]=block.officers
		for officer in block.officers: by_id[int(officer.index)+1]=officer
	for side in sides:
		var roster: Array=side.get("roster",[]);var ranks: Array=side.get("ranks",[])
		for i in range(mini(roster.size(),ranks.size())):
			if by_id.has(int(roster[i])) and int(ranks[i])>0: by_id[int(roster[i])].level=clampi(int(ranks[i])-1,0,9)
	for id in by_id:
		if id<=33 and int(by_id[id].get("level",0))==0: by_id[id].level=5
	return result
