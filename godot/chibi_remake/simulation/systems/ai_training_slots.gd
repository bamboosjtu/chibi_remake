extends RefCounted
## 陆军待命槽。仅成功出生回调计数；UID历史保留到整队死亡或显式解散。
const Access = preload("res://simulation/ports/ai_access.gd")
var host: Access
var records := {}
var serial := 0

func _init(h: Object) -> void:
	host = h.simulation_access("ai") if h.has_method("simulation_access") else h

static func key_for(owner: int, slot: int) -> String:
	return "%d/%d" % [owner,slot]

static func capacity(slot: int) -> int:
	return 5 if slot == 1 else 8

static func expected_family(slot: int, count: int) -> int:
	if slot in [0,3]: return 0 if count<4 else 1
	if slot==1: return 2
	return 3 if count<2 else 1

static func family(unit: int) -> int:
	if unit in [45,39]: return 0
	if unit in [32,38]: return 1
	if unit in [36,37]: return 2
	if unit == 34: return 3
	return -1

func record(owner: int, slot: int) -> Dictionary:
	var key := key_for(owner,slot)
	if not records.has(key):
		records[key] = {"members":[],"ready":false,"pendingUid":-1,"pendingToken":0}
	return records[key]

func refresh(owner: int) -> void:
	for slot in range(4):
		var key := key_for(owner,slot)
		if not records.has(key): continue
		var rec: Dictionary = records[key]
		if rec.members.is_empty(): continue
		var live: bool = host.units.any(func(u): return rec.members.has(int(u.uid)) and bool(u.alive) and float(u.die_t)<0)
		if not live and int(rec.pendingUid)<0:
			# 已付费订单仍属于本批；等待到位/取消，不把后半段步兵错当下一批首员。
			rec.members.clear();rec.ready=false

func line_busy(owner: int, unit: int) -> bool:
	return host.trainings.any(func(tr): return int(tr.get("owner",tr.b.owner))==owner and family(int(tr.unit))==family(unit))

func forming(u: Dictionary) -> bool:
	for key in records:
		var rec: Dictionary=records[key]
		if not bool(rec.ready) and rec.members.has(int(u.uid)): return true
	return false

func dispatch(owner: int, slot: int, army: Array) -> bool:
	refresh(owner)
	var rec := record(owner,slot)
	if bool(rec.ready) or int(rec.pendingUid)>=0: return false
	var have: Array=host.ai_building_kinds(owner)
	if slot in [0,3] and (not have.has(12) or not have.has(14)): return false
	if slot==1 and not have.has(6): return false
	if slot==2 and not have.has(8): return false
	var count: int=rec.members.size()
	var unit: int=int(army[0 if count<4 else 1]) if slot in [0,3] else (int(army[2]) if slot==1 else (34 if count<2 else int(army[1])))
	if line_busy(owner,unit): return false
	var building: Dictionary=host.ai_production_building(owner,unit)
	if building.is_empty(): return false
	var cost: Dictionary=host.ai_unit_cost(unit)
	if not host.ai_can_afford(owner,cost):
		host.ai_gift(owner,1000.0,1500.0,1000.0)
		return false
	if not host._queue_train(owner,building,unit): return false
	serial+=1
	var order: Dictionary=host.trainings.back()
	order.aiSlot=slot;order.aiToken=serial
	rec.pendingUid=int(building.uid);rec.pendingToken=serial
	return true

func _matching(order: Dictionary) -> Dictionary:
	if not order.has("aiSlot") or not order.has("aiToken"): return {}
	var key := key_for(int(order.owner),int(order.aiSlot))
	var rec: Dictionary=records.get(key,{})
	if rec.is_empty() or int(rec.pendingUid)!=int(order.b.uid) or int(rec.pendingToken)!=int(order.aiToken): return {}
	return rec

func completed(order: Dictionary, unit: Dictionary) -> void:
	var rec := _matching(order)
	if rec.is_empty(): return # 重复回调/旧订单不能串入下一批。
	refresh(int(order.owner))
	rec.pendingUid=-1;rec.pendingToken=0
	if not rec.members.has(int(unit.uid)): rec.members.append(int(unit.uid))
	rec.ready=rec.members.size()>=capacity(int(order.aiSlot))

func cancelled(order: Dictionary) -> void:
	var rec := _matching(order)
	if not rec.is_empty(): rec.pendingUid=-1;rec.pendingToken=0

func disband(owner: int, slot: int) -> void:
	var key := key_for(owner,slot)
	if not records.has(key): return
	var rec: Dictionary=records[key]
	for order in host.trainings.duplicate():
		if int(order.get("owner",-1))==owner and int(order.get("aiSlot",-1))==slot:
			host._cancel_training(order.b)
	# 成员仍存活并保留身份/生命，不删除或自动占将。
	rec.members.clear();rec.ready=false;rec.pendingUid=-1;rec.pendingToken=0

func snapshot() -> Dictionary:
	return {"serial":serial,"records":records.duplicate(true)}

func restore(value: Dictionary) -> void:
	serial=int(value.get("serial",0));records=value.get("records",{}).duplicate(true)
	for key in records:
		var rec: Dictionary=records[key]
		rec.pendingUid=int(rec.pendingUid);rec.pendingToken=int(rec.pendingToken)
		for i in range(rec.members.size()):rec.members[i]=int(rec.members[i])

static func integer(value: Variant, minimum: int=0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<=2147483647

func valid_snapshot(value: Variant, ids: Dictionary, orders: Array, next_uid: int) -> bool:
	if not value is Dictionary or not integer(value.get("serial",0)) or not value.get("records",{}) is Dictionary: return false
	var table: Dictionary=value.get("records",{})
	var members := {};var pending := {};var tokens := {};var lines := {}
	for key in table:
		var parts := str(key).split("/")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var owner:=int(parts[0]);var slot:=int(parts[1])
		if str(key)!=key_for(owner,slot) or not host.ai_owners().has(owner) or slot<0 or slot>3: return false
		var rec=table[key]
		if not rec is Dictionary or not rec.get("members") is Array or not rec.get("ready") is bool: return false
		if rec.members.size()>capacity(slot) or bool(rec.ready)!=(rec.members.size()==capacity(slot)): return false
		if not integer(rec.get("pendingUid"),-1) or not integer(rec.get("pendingToken")): return false
		var uid:=int(rec.pendingUid);var token:=int(rec.pendingToken)
		if (uid<0)!=(token==0) or token>int(value.get("serial",0)): return false
		if uid>=0:
			if bool(rec.ready) or pending.has(uid) or tokens.has(token) or not ids.has(uid): return false
			var building: Dictionary=ids[uid]
			if int(building.owner)!=owner or not bool(building.building) or not bool(building.alive) or float(building.dieT)>=0: return false
			pending[uid]=str(key);tokens[token]=true
		for i in range(rec.members.size()):
			var member=rec.members[i]
			if not integer(member) or int(member)>=next_uid or members.has(int(member)): return false
			members[int(member)]=true
			if ids.has(int(member)):
				var unit: Dictionary=ids[int(member)]
				if int(unit.owner)!=owner or bool(unit.building) or family(int(unit.unit))!=expected_family(slot,i): return false
	for order in orders:
		if not order.has("aiSlot") and not order.has("aiToken"): continue # 旧档普通订单无槽关联。
		if not integer(order.get("aiSlot")) or int(order.aiSlot)>3 or not integer(order.get("aiToken"),1): return false
		var key:=key_for(int(order.owner),int(order.aiSlot));var uid:=int(order.buildingUid)
		if pending.get(uid,"")!=key or int(table[key].pendingToken)!=int(order.aiToken): return false
		if family(int(order.unit))!=expected_family(int(order.aiSlot),table[key].members.size()): return false
		var line:="%d/%d"%[int(order.owner),family(int(order.unit))]
		if lines.has(line): return false
		lines[line]=true
		pending.erase(uid)
	return pending.is_empty()
