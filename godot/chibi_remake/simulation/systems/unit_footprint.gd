extends RefCounted
## CONF-20 单位占格形状。偏移直接加在锚点格上；按锚点格 y 的奇偶选表。
## 档 0=1 格、1=4 格、2=9 格、3=16 格；档 N 取前 N*N 项。

const EVEN := [
	Vector2i(0, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, -2),
	Vector2i(-1, -2), Vector2i(-1, -3), Vector2i(1, -2), Vector2i(0, -3),
	Vector2i(0, -4), Vector2i(-2, -3), Vector2i(-1, -4), Vector2i(-1, -5),
	Vector2i(1, -3), Vector2i(1, -4), Vector2i(0, -5), Vector2i(0, -6),
]
const ODD := [
	Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, -2),
	Vector2i(-1, -2), Vector2i(0, -3), Vector2i(1, -2), Vector2i(1, -3),
	Vector2i(0, -4), Vector2i(-1, -3), Vector2i(-1, -4), Vector2i(0, -5),
	Vector2i(2, -3), Vector2i(1, -4), Vector2i(1, -5), Vector2i(0, -6),
]

## 兵种 id → 占格档（CONF-20 实证列表；未列出的按档 0）。
const CLASS_BY_UNIT := {
	# CONF-20: buildings use the same square shape table as mobile units.
	0: 2, 1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2, 8: 2, 9: 2,
	10: 1, 11: 1, 12: 1, 13: 1, 14: 1, 15: 1, 16: 1, 17: 1,
	18: 0, 19: 0, 20: 2, 21: 0, 22: 2, 23: 2, 24: 1, 25: 1, 26: 0,
	27: 0, 28: 0, 29: 0, 30: 0, 31: 0, 32: 0, 33: 0, 35: 0, 36: 0,
	38: 0, 39: 0, 45: 0, 46: 0, 50: 0, 51: 0,
	34: 1, 37: 1, 40: 1, 41: 1, 42: 1, 43: 1, 44: 1, 47: 1, 48: 1, 52: 1,
	49: 3,
}

static func class_of(unit_id: int) -> int:
	return int(CLASS_BY_UNIT.get(unit_id, 0))

## 档位 + 锚点 y 奇偶 → 相对偏移表（R04 导航也用它做整块校验/图缓存）。
static func offsets(cls: int, anchor_y: int) -> Array:
	var side := int(cls) + 1
	var count := side * side
	if count <= 1:
		return [Vector2i.ZERO]
	var table: Array = ODD if (anchor_y & 1) == 1 else EVEN
	return table.slice(0, mini(count, table.size()))

static func shape(unit_id: int, anchor: Vector2i) -> Array:
	var cls := class_of(unit_id)
	if cls + 1 <= 1:
		return [anchor]
	var out: Array = []
	for off in offsets(cls, anchor.y):
		out.append(anchor + off)
	return out
