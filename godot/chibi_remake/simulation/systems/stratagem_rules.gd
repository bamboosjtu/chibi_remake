extends RefCounted
## research/units + research/magics: team targeting, flags and queued idle actions.
const STATUS_FIELDS := {1:"inspired_t",2:"haste_t",3:"slow_t",4:"farsight_t",5:"confused_t",6:"ambush_t",7:"rolling_t"}
const CONFUSION := 0x1B
const ROLLING := 0x1C
static var tuning:Dictionary={}
const Access = preload("res://simulation/ports/stratagem_rules_access.gd")
var host: Access
func _init(h:Object) -> void:host = h.simulation_access("stratagem_rules") if h.has_method("simulation_access") else h
static func config() -> Dictionary:
	if tuning.is_empty():tuning=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/unit_tuning.json"))
	return tuning

func eligible(unit:Dictionary, owner:int) -> bool:
	return bool(unit.get("alive",false)) and float(unit.get("die_t",-1))<0 and not bool(unit.get("is_building",false)) \
		and int(unit.get("owner",-1))==owner and not bool(unit.get("attached",false)) and int(unit.get("site_inside_uid",-1))<0

func target_team(target:Dictionary) -> Array:
	var owner:=int(target.get("owner",-1))
	if not eligible(target,owner) or not host.units.any(func(u):return is_same(u,target)):return []
	var commander:Dictionary=host._commander_for(target)
	if commander.is_empty():return [target]
	if not eligible(commander,owner):return []
	var index:=int(commander.officer.index)
	# Canonical team order: commander first, then world-list members. Clicking a
	# different member must not change which first 15 recipients receive an effect.
	var result:Array=[commander]
	for member in host.units:
		if result.size()>=15:break
		if eligible(member,owner) and int(member.get("group_officer",-1))==index and not is_same(member,commander):result.append(member)
	return result

static func set_status(unit:Dictionary, state:int) -> void:
	unit[STATUS_FIELDS[state]]=int(config().statusTicks)
	if state==2:unit.slow_t=0
	if state==3:unit.haste_t=0
	if state==7:unit.rolling_ticks=0
	if state in [5,7]:
		var task:int=CONFUSION if state==5 else ROLLING
		if not unit.has("effect_tasks"):unit.effect_tasks=[]
		if int(unit.get("effect_task",0))!=task and task not in unit.effect_tasks:unit.effect_tasks.append(task)

static func active(unit:Dictionary) -> bool:
	return int(unit.get("effect_task",0)) in [CONFUSION,ROLLING]

static func task_alive(unit:Dictionary, task:int) -> bool:
	return int(unit.get("confused_t" if task==CONFUSION else "rolling_t",0))>0

static func begin_update(unit:Dictionary) -> void:
	if active(unit) and not task_alive(unit,int(unit.effect_task)):unit.effect_task=0
	var pending:Array=unit.get("effect_tasks",[])
	while not active(unit) and str(unit.get("state",""))=="idle" and not pending.is_empty() \
			and not bool(unit.get("attached",false)) and int(unit.get("site_inside_uid",-1))<0:
		var task:int=int(pending.pop_front())
		if task_alive(unit,task):unit.effect_task=task
	unit.effect_tasks=pending

func step_effects(unit:Dictionary) -> void:
	if int(unit.get("rolling_t",0))<=0:unit.rolling_ticks=0
	if int(unit.get("effect_task",0))!=ROLLING or not task_alive(unit,ROLLING) or not eligible(unit,int(unit.owner)):return
	unit.rolling_ticks=int(unit.get("rolling_ticks",0))+1
	if int(unit.rolling_ticks)<30:return
	unit.rolling_ticks=0
	var radius:float=host.visibility.effective_vision(unit)*float(host.tile_w)
	# Original task takes the first scan entry, rather than the nearest enemy.
	for enemy in host.units:
		if not bool(enemy.alive) or float(enemy.die_t)>=0 or bool(enemy.get("attached",false)) or int(enemy.get("site_inside_uid",-1))>=0:continue
		if not host._hostile_owners(int(unit.owner),int(enemy.owner)):continue
		if Vector2(enemy.ax-unit.ax,enemy.ay-unit.ay).length_squared()>radius*radius:continue
		var commander:Dictionary=host._commander_for(enemy)
		if commander.is_empty():return
		commander.status_173=maxi(0,int(commander.get("status_173",70))-50)
		unit.rolling_t=0;unit.effect_task=0
		break

static func valid_snapshot(state:Dictionary) -> bool:
	var pending=state.get("effect_tasks",[])
	if not pending is Array or pending.size()>2:return false
	var seen:Array=[]
	for task in pending:
		if not (task is int or task is float) or not is_finite(float(task)) or float(task)!=floorf(float(task)) or int(task) not in [CONFUSION,ROLLING] or int(task) in seen:return false
		seen.append(int(task))
	var running=state.get("effect_task",0)
	return (running is int or running is float) and is_finite(float(running)) and float(running)==floorf(float(running)) and int(running) in [0,CONFUSION,ROLLING] and int(running) not in seen

static func restore(state:Dictionary, unit:Dictionary) -> void:
	unit.effect_tasks=state.get("effect_tasks",[]).map(func(task):return int(task))
	unit.effect_task=int(state.get("effect_task",0))
	# Old saves used immediate confusion. Keep an existing pause until that flag ends.
	if not state.has("effect_task") and int(unit.get("confused_t",0))>0:unit.effect_task=CONFUSION
