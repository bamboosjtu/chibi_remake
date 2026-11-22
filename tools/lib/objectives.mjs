// 从 CB.EXE 反编译里抽取「关卡目标」表。
// 目标求值器 = FUN_00404800（FUN_00404590 只是 14 字节的 thunk）。
// 8 个关卡有**写死的脚本目标**：5, 8, 14(0xe), 19(0x13), 20(0x14), 27(0x1b), 29(0x1d), 30(0x1e)
// 其余 26 关走默认的歼灭规则。
//
// 目标形状统一为：**持有武将 N 的单位进入地块矩形 R**，带 per-mission 锁存器
// (DAT_00487838/3a/3c[mission*5])。少数用「与另一单位相距 ±10 格」代替绝对矩形。
//
// 字段：officer = 单位 +0x150 的武将索引；rect = [x0,x1,y0,y1]（闭区间，格）
import fs from 'node:fs';

const OBJECTIVES = {
  schemaVersion: 1,
  source: 'CB.EXE FUN_00404800 @0x404800 (thunk FUN_00404590 @0x404590)',
  note: '带 scripted 目标的关卡；其余关卡用默认歼灭规则。rect = [x0,x1,y0,y1] 闭区间。',
  missions: {
    5: {
      stages: [
        { kind: 'officer_in_rect', officer: 40, rect: [47, 65, 126, 144], latch: 'a',
          effect: 'sound3; 玩家 -50 资源' },
        { kind: 'officer_in_rect', officer: 40, rect: [87, 105, 266, 284], latch: 'b', win: true },
      ],
    },
    8: {
      stages: [
        { kind: 'officer_in_rect', officer: 34, rect: [1, 19, 76, 94], latch: 'a',
          effect: 'sound6; DAT_00485500=1; 4× FUN_00459c00(1,…); FUN_0041d660(1)' },
        { kind: 'officer_in_rect', officer: 34, rect: [91, 109, 291, 309], latch: 'b', win: true },
        { kind: 'enemy_in_rect', rect: [78, 96, 253, 271], then_officer_in_rect: { officer: 35, rect: [82, 100, 264, 282] },
          latch: 'c', effect: '玩家 -40 资源; sound7' },
      ],
    },
    14: {
      stages: [
        { kind: 'officer_near_unit', officer: 34, radius: 10, latch: 'a', effect: '玩家 -20; sound9', returns: 0 },
        { kind: 'officer_near_unit', officer: 35, radius: 10, latch: 'b', effect: '玩家 -20; sound10', returns: 0 },
        { kind: 'officer_near_unit', officer: 36, radius: 10, latch: 'c', win: true },
        { kind: 'officer_in_rect', officer: 60, rect: [11, 29, 34, 52], win: true },
      ],
    },
    19: {
      stages: [
        { kind: 'unit_in_rect', rect: [41, 59, 51, 69], latch: 'a' },
        { kind: 'enemy_unit_present', effect: '给该敌将 +DAT_0048534c 经验; 下达指令(码5,模式9)' },
      ],
    },
    20: {
      stages: [{ kind: 'unit_in_rect', rect: [54, 72, 232, 250], latch: 'a' }],
    },
    27: {
      stages: [{ kind: 'latch_only', latch: 'a', note: 'case 0x1b 只写锁存器，具体条件未在抽取范围内' }],
    },
    29: {
      stages: [{ kind: 'unit_in_rect', rect: [45, 63, 162, 180], latch: 'a' }],
    },
    30: {
      stages: [
        { kind: 'officer_in_rect', officer: 60, rect: [11, 29, 34, 52], note: '与 14 关同一矩形' },
        { kind: 'officer_near_unit', officer: 60, radius: 10, latch: 'a', returns: 0 },
        { kind: 'officer_near_unit', officer: 60, radius: 10, latch: 'b', returns: 0 },
        { kind: 'officer_near_unit', officer: 60, radius: 10, latch: 'c', win: true },
      ],
      note: '三段锁存：必须先满足绝对矩形，再依次靠近 local_20/local_28/local_24 三个单位',
    },
  },
};

const out = process.argv[2] || '_work/dec/objectives.json';
fs.writeFileSync(out, JSON.stringify(OBJECTIVES, null, 1));
const ids = Object.keys(OBJECTIVES.missions).map(Number).sort((a, b) => a - b);
console.log(`objectives: ${ids.length} missions with scripted goals -> ${out}`);
console.log(`  missions: ${ids.join(', ')}`);
console.log(`  others (${34 - ids.length}): default annihilation rule`);
