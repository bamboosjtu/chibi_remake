extends RefCounted
## Deterministic AI constants shared by the facade and its state.
const THINK_PERIOD := 41          # DAT_00485648[owner] -> 0x28
const BUILD_PLAN_PERIOD := 22     # DAT_004856b0[owner] -> 0x15
const BUILD_STATE_PERIOD := 11    # CONF-16：档位0/1施工状态机每11帧
const INTERCEPT_PERIOD := 30      # DAT_004856ac -> 0x1e
const ASSAULT_PERIOD := 70        # u_FFFFF_00485668[owner] -> 'F'
const ASSAULT_PERIOD_URGENT := 6  # 人类单位 < 6 时
const AI_MONEY := 20000.0         # DAT_004b8d08[owner] = 20000
const GIFT_WOOD := 1000.0
const GIFT_FOOD := 1500.0
const GIFT_STONE := 1000.0
const HUMAN_GOLD_FOR_ASSAULT := 15000.0

## 当前章节范围与玩家共用用户确认的100/200人生产准入；后续兵种保留在GAP。
const ARMY_BY_TIER := [[45,32,36], [39,38,37]]

## 该方当前的兵种表（按自身等级 0..2 取；超出范围钳制）
const HUMAN_WEAK_UNITS := 6
const INTERCEPT_RADIUS := 90.0
const Access = preload("res://simulation/ports/ai_access.gd")
const PLAN_TO_BUILDING := {
	1: 0, 2: 1, 3: 8, 4: 9, 5: 0xe, 6: 0xf, 7: 6, 8: 7, 9: 0xc, 10: 0xd,
	11: 0x12, 12: 0x13, 13: 2, 14: 3, 15: 10, 16: 0xb, 17: 4, 18: 5, 19: 0x14, 20: 0x17,
}

## **归属奇偶层** —— 订正：此前记录里说"REA 反编译没有奇偶证据"是**错的**。
## 证据就在 `FUN_0046e4b0` 里（`_work/fun_46e4b0.c` 第 27/31/40/41/53/54 行）：
##     if ((param_1 == 1) || (param_1 == 3)) { … = 0xf; return; }   // 奇数归属
##     if ((param_1 != 2) && (param_1 != 4)) { return; } … = 0x10;  // 偶数归属
## `param_1` 就是归属 id。它写成**显式比较**而不是 `% 2`/`& 1`，
## 所以之前按"奇偶形状"去 grep 才会一无所获。
##
## 语义：**同一建筑槽，奇数归属(1,3) 与偶数归属(2,4) 选不同的计划项**，
## 落到的正是 DATA.EXP 里那对"同建筑的两个阵营版本"。
## 下表的键 = 建筑种类（取该对的偶数 id），值 = [奇数归属用的项, 偶数归属用的项]。
const PLAN_PAIR := {
	0:  [1,    2],      # 帅帐      → 0 / 1
	2:  [0xd,  0xe],    # 武器库    → 2 / 3
	4:  [0x11, 0x12],   # 木材场    → 4 / 5
	6:  [7,    8],      # 骑兵所    → 6 / 7
	8:  [3,    4],      # 车兵所    → 8 / 9
	12: [9,    10],     # 步兵所    → 12 / 13
	14: [5,    6],      # 弓兵所    → 14 / 15
	10: [0xf,  0x10],   # 粮仓 → 10 / 11，必须和实际建筑类型归类一致。
	18: [0xb,  0xc],    # 箭楼      → 18 / 19
	20: [0x13, 0x13],   # 船坞      → 20（原版无配对）
	22: [0x14, 0x14],   # 钱庄      → 23（原版无配对）
}

## 该归属要盖这一"种类"时，原版会写哪个计划项（奇偶决定）
## static：main.gd 的**玩家侧建造**菜单要用同一份「计划项 → 建筑 id」证据，
## 不能另造一套（那会让玩家和 AI 造出不同阵营版本的建筑）。
const BUILD_PRIORITY_KINDS := [0, 12, 2, 6, 8, 14, 4, 10, 18, 20, 22]

## 原版 FUN_0046e4b0：挑下一个要盖的建筑，写计划槽 DAT_005d2000/0x5d2004
