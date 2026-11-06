extends RefCounted
## Canonical subsystem snapshots; no scene nodes or presentation clocks.
## `hasher` is supplied by the caller and must expose save_checksum(Dictionary);
## keeping it out of here is what lets the simulation run without a scene tree.
static func snapshot(host) -> Dictionary:
	var world:Array=[]
	var commands:Array=[]
	for u in host.units:
		world.append([int(u.uid),int(u.unit),int(u.owner),float(u.ax),float(u.ay),float(u.hp),bool(u.alive)])
		var record:Dictionary={"uid":int(u.uid)}
		for key in ["state","pi","cool","site","build_t","build_frame","carry","carry_kind","group_officer","officer","action_phase","action_wait"]:record[key]=u.get(key)
		record["targetUid"]=int(u.target.get("uid",-1)) if u.get("target") is Dictionary else -1
		var points:Array=[]
		for point in u.get("path",[]):points.append([point.x,point.y])
		record["path"]=points;commands.append(record)
	var production:Array=[]
	for job in host.trainings:
		production.append([int(job.b.uid),int(job.unit),float(job.t),job.get("cost",{})])
	var values:Dictionary={"world":world,"economy":{"resources":{"gold":host.gold,"wood":host.wood,"food":host.food,"stone":host.stone},"tech":host.player_tech,"armyTech":host.army_tech,"research":host.research_jobs,"production":production},"combat":{"commands":commands,"projectiles":host.projectiles.snapshot(),"fire":host.fire_fields.snapshot(),"rng":str(host.simulation_rng.state)},"ai":host.ai.snapshot() if host.ai!=null else {},"scenario":{"latches":host.task_latches,"events":host.task_events,"done":host.objective_done,"end":host.game_end,"terrain":host.terrain_changes}}
	if host.auto_control: values.combat["autoControl"] = true
	if host.cheats_enabled or host.cheat_build_any or host.cheat_invulnerable or host.cheat_reveal:
		values.combat["cheats"] = [host.cheats_enabled,host.cheat_build_any,host.cheat_invulnerable,host.cheat_reveal]
	return values

static func sections(host, hasher) -> Dictionary:
	var values := snapshot(host)
	var result: Dictionary = {}
	for key in values:result[key]=hasher.save_checksum(values[key] if values[key] is Dictionary else {"rows":values[key]})
	result["total"]=hasher.save_checksum(result)
	return result
