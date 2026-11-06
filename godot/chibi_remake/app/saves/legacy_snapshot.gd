extends RefCounted
## Preserve the v1/v2 positional and v3 UID migration contracts.
var host: Object
var _apply_unit_record: Callable
var _restore_trainings: Callable

func _init(battle: Object, record: Callable, trainings: Callable) -> void:
	host = battle
	_apply_unit_record = record
	_restore_trainings = trainings

func _apply_v3(d: Dictionary, arr: Array) -> int:
	var by_uid := {}
	var by_map_index := {}
	for u in host.units:
		by_uid[int(u.uid)] = u
		if u.has("map_index"):
			by_map_index[int(u.map_index)] = u

	# 快照里"点名"过的地图对象（无论死活）—— 没被点名的就是已经阵亡并被清理的
	var mentioned := {}
	for rec in arr:
		if rec is Dictionary and bool(rec.get("mapObject", false)):
			mentioned[int(rec.get("uid", -1))] = true

	var applied := 0
	var respawned := 0
	var skipped := 0
	var max_uid := -1
	for rec in arr:
		if not (rec is Dictionary):
			skipped += 1
			continue
		var uid := int(rec.get("uid", -1))
		var unit_id := int(rec.get("unit", -1))
		var owner := int(rec.get("owner", -1))
		var is_map := bool(rec.get("mapObject", false))
		var target: Dictionary = by_uid.get(uid, {})
		if not target.is_empty() and (int(target.unit) != unit_id or int(target.owner) != owner):
			target = {}
		if target.is_empty() and is_map:
			var cand: Dictionary = by_map_index.get(int(rec.get("mapIndex", -1)), {})
			if not cand.is_empty() and int(cand.unit) == unit_id and int(cand.owner) == owner:
				target = cand
		if target.is_empty():
			if host.commands.world._spawn_unit(unit_id, owner, float(rec.get("x", 0.0)), float(rec.get("y", 0.0))):
				target = host.units[host.units.size() - 1]
				respawned += 1
			else:
				skipped += 1
				continue
		if host.view != null: host.view.rekey_unit(target, uid)
		target["uid"] = uid                      # ARCH-002：身份写回
		max_uid = maxi(max_uid, uid)
		_apply_unit_record.call(target, rec)
		applied += 1

	# ARCH-001：完整快照语义 —— 缺席的地图对象按"已阵亡并清理"处理
	# 注意：host.<member> 是动态取到的 Variant，`:=` 推不出类型（会直接 Parse Error），
	# 所以凡是从宿主取来的量都写显式类型。
	var removed := 0
	var i: int = host.units.size() - 1
	while i >= 0:
		var u: Dictionary = host.units[i]
		if bool(u.get("map_object", false)) and not mentioned.has(int(u.uid)):
			host.commands.world._free_unit_at(i)
			removed += 1
		i -= 1

	host.next_uid = maxi(maxi(int(d.get("nextUid", 0)), max_uid + 1), int(host.next_uid))
	_restore_trainings.call(d)
	host.game_end = int(d.get("gameEnd", 0))
	print("save v3 applied: %d/%d units (%d respawned, %d skipped), %d stale map objects removed, nextUid=%d, trainings=%d" % [
		applied, arr.size(), respawned, skipped, removed, int(host.next_uid), host.trainings.size()])
	return applied

## v1/v2：数组记录。没有 mapObject/mapIndex，无法做快照语义，按旧行为尽力恢复。

func _apply_legacy(d: Dictionary, arr: Array, ver: int) -> int:
	var by_uid := {}
	var by_map_index := {}
	for u in host.units:
		by_uid[int(u.uid)] = u
		if u.has("map_index"):
			by_map_index[int(u.map_index)] = u
	var applied := 0
	var respawned := 0
	var skipped := 0
	for ri in range(arr.size()):
		var rec = arr[ri]
		if not (rec is Array):
			skipped += 1
			continue
		if ver < 2 or rec.size() < 9:
			if rec.size() >= 4 and ri < host.units.size() and bool(host.units[ri].get("map_object", false)):
				_apply_unit_record.call(host.units[ri], {
					"alive": int(rec[0]) != 0, "x": float(rec[1]), "y": float(rec[2]),
					"hp": float(rec[3]), "dieT": -1.0, "state": "idle",
				})
				applied += 1
			else:
				skipped += 1
			continue
		var uid := int(rec[0])
		var owner := int(rec[5])
		var unit_id := int(rec[6])
		var target: Dictionary = by_uid.get(uid, {})
		if not target.is_empty() and (int(target.unit) != unit_id or int(target.owner) != owner):
			target = {}
		if target.is_empty() and bool(rec[8]):
			var cand: Dictionary = by_map_index.get(int(rec[9]) if rec.size() > 9 else -1, {})
			if not cand.is_empty() and int(cand.unit) == unit_id and int(cand.owner) == owner:
				target = cand
		if target.is_empty():
			if host.commands.world._spawn_unit(unit_id, owner, float(rec[2]), float(rec[3])):
				target = host.units[host.units.size() - 1]
				if host.view != null: host.view.rekey_unit(target, uid)
				target["uid"] = uid
				respawned += 1
			else:
				skipped += 1
				continue
		_apply_unit_record.call(target, {
			"alive": int(rec[1]) != 0, "x": float(rec[2]), "y": float(rec[3]),
			"hp": float(rec[4]), "dieT": -1.0, "state": "idle",
		})
		applied += 1
	print("save v%d (legacy) applied: %d/%d units (%d respawned, %d skipped)" % [ver, applied, arr.size(), respawned, skipped])
	return applied

## 把一个存档记录写进实体（v3 具名字段；legacy 也归一到同一形状）
