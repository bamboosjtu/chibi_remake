extends RefCounted
## CONF-18E 水军槽：0/1 槽快船各 8，3 槽运输船 1；2 槽不参与。
## 只在行为档位 1 驱动；四槽“在途”全 0 才派下一艘。
const Access = preload("res://simulation/ports/ai_access.gd")
var host: Access
var records := {}
var serial := 0

func _init(h: Object) -> void:
	host = h.simulation_access("ai") if h.has_method("simulation_access") else h

static func capacity(slot: int) -> int:
	if slot == 3: return 1
	if slot in [0, 1]: return 8
	return 0

static func unit_for(slot: int) -> int:
	return 47 if slot == 3 else 46

static func active(slot: int) -> bool:
	return slot in [0, 1, 3]

func record(owner: int, slot: int) -> Dictionary:
	var key := "%d/%d" % [owner, slot]
	if not records.has(key):
		records[key] = {"members": [], "pending": false, "token": 0, "ready": false, "flagship": -1}
	return records[key]

func refresh(owner: int) -> void:
	for slot in [0, 1, 3]:
		var key := "%d/%d" % [owner, slot]
		if not records.has(key): continue
		var rec: Dictionary = records[key]
		var live: Array = []
		for uid in rec.members:
			var found := false
			for u in host.units:
				if int(u.get("uid", -1)) == int(uid) and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0:
					found = true; break
			if found: live.append(uid)
		rec.members = live
		if int(rec.flagship) >= 0 and not live.has(int(rec.flagship)):
			rec.flagship = int(live[0]) if not live.is_empty() else -1
		rec.ready = live.size() >= capacity(slot)

func step(owner: int, allowed: Array) -> void:
	if int(host.ai_behavior(owner)) != 1: return
	refresh(owner)
	var any_transit := false
	for slot in [0, 1, 3]:
		if bool(record(owner, slot).pending): any_transit = true
	for slot in allowed:
		if not active(int(slot)): continue
		var cap := capacity(int(slot))
		var rec := record(owner, int(slot))
		if rec.members.size() >= cap:
			rec.ready = true
			continue
		if bool(rec.pending) or any_transit: continue
		var unit := unit_for(slot)
		var building: Dictionary = host.ai_production_building(owner, unit)
		if building.is_empty(): continue
		if not host._queue_train(owner, building, unit): continue
		serial += 1
		var order: Dictionary = host.trainings.back()
		order.navalSlot = slot
		order.navalToken = serial
		rec.pending = true
		rec.token = serial
		any_transit = true

func completed(order: Dictionary, unit: Dictionary) -> void:
	if not order.has("navalSlot"): return
	var rec := record(int(order.owner), int(order.navalSlot))
	if int(rec.token) != int(order.get("navalToken", -1)): return
	rec.pending = false
	rec.token = 0
	rec.members.append(int(unit.uid))
	if int(rec.flagship) < 0: rec.flagship = int(unit.uid)
	rec.ready = rec.members.size() >= capacity(int(order.navalSlot))

func cancelled(order: Dictionary) -> void:
	if not order.has("navalSlot"): return
	var rec := record(int(order.owner), int(order.navalSlot))
	rec.pending = false; rec.token = 0

func snapshot() -> Dictionary:
	# A casualty can happen after the latest AI think. Serialize live membership
	# and derived readiness so the slot remains loadable before the next refresh.
	var owners := {}
	for key in records:
		owners[int(str(key).get_slice("/", 0))] = true
	for owner in owners:
		refresh(int(owner))
	return {"serial": serial, "records": records.duplicate(true)}

func restore(value: Dictionary) -> void:
	serial = int(value.get("serial", 0))
	records = value.get("records", {}).duplicate(true)
	# 与陆军槽一致：JSON 读回的数值统一转 int，成员/旗舰保持稳定 UID。
	for key in records:
		var rec: Dictionary = records[key]
		rec.pending = bool(rec.get("pending", false))
		rec.ready = bool(rec.get("ready", false))
		rec.token = int(rec.get("token", 0))
		rec.flagship = int(rec.get("flagship", -1))
		var normalized: Array = []
		for member in rec.get("members", []):
			normalized.append(int(member))
		rec.members = normalized

static func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= 2147483647

## R16：与陆军槽对等的完整校验。水军槽直接恢复结构字段，坏档必须在交换世界**之前**拒绝：
## 权威键 owner/slot、槽容量/兵种、成员 UID 唯一且归属正确、旗舰属于成员、
## pending 与 token 的配对、以及每个在途记录必须有真实且同属的海军订单。
func valid_snapshot(value: Variant, ids: Dictionary, orders: Array, next_uid: int) -> bool:
	if not value is Dictionary: return false
	if not integer(value.get("serial", 0)): return false
	if not value.get("records", {}) is Dictionary: return false
	var table: Dictionary = value.get("records", {})
	var serial_value := int(value.get("serial", 0))
	var owners: Array = host.ai_owners()
	var members := {}
	var tokens := {}
	for key in table:
		var parts := str(key).split("/")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var owner := int(parts[0])
		var slot := int(parts[1])
		if str(key) != "%d/%d" % [owner, slot]: return false
		if not owners.has(owner) or not active(slot): return false
		var rec = table[key]
		if not rec is Dictionary: return false
		if not rec.get("members") is Array: return false
		if not rec.get("pending") is bool or not rec.get("ready") is bool: return false
		if not integer(rec.get("token")) or not integer(rec.get("flagship"), -1): return false
		var token := int(rec.token)
		var flagship := int(rec.flagship)
		if token > serial_value: return false
		if bool(rec.pending) != (token > 0): return false
		if token > 0:
			if tokens.has(token): return false
			tokens[token] = true
		if rec.members.size() > capacity(slot): return false
		if bool(rec.ready) != (rec.members.size() >= capacity(slot)): return false
		if flagship < 0:
			if not rec.members.is_empty(): return false
		# JSON numbers are floats; Array.has(int_uid) does not match float_uid.
		elif not rec.members.any(func(member): return integer(member) and int(member) == flagship):
			return false
		for member in rec.members:
			if not integer(member) or int(member) >= next_uid: return false
			if members.has(int(member)): return false
			members[int(member)] = true
			if ids.has(int(member)):
				var unit: Dictionary = ids[int(member)]
				if int(unit.owner) != owner or bool(unit.building) or int(unit.unit) != unit_for(slot): return false
	# 每个 pending 槽必须对应一条真实订单；重复回调/取消后的悬空 token 都拒绝。
	var linked := {}
	for order in orders:
		if not order.has("navalSlot") and not order.has("navalToken"): continue
		if not integer(order.get("navalSlot")) or not integer(order.get("navalToken"), 1): return false
		var oowner := int(order.get("owner", -1))
		var oslot := int(order.navalSlot)
		var otoken := int(order.navalToken)
		if not owners.has(oowner) or not active(oslot): return false
		var okey := "%d/%d" % [oowner, oslot]
		if not table.has(okey): return false
		var orec: Dictionary = table[okey]
		if not bool(orec.pending) or int(orec.token) != otoken or linked.has(okey): return false
		linked[okey] = true
		var building_uid := int(order.get("buildingUid", -1))
		if not ids.has(building_uid): return false
		var building: Dictionary = ids[building_uid]
		if int(building.owner) != oowner or not bool(building.building) or not bool(building.alive) or float(building.dieT) >= 0: return false
		# 船坞是成对的 20/21；工地不能挂船。
		if int(building.unit) - int(building.unit) % 2 != 20 or bool(building.simulation.get("site", false)): return false
		if int(order.get("unit", -1)) != unit_for(oslot): return false
	for key in table:
		if bool(table[key].pending) and not linked.has(key): return false
	return true
