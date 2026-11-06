#!/usr/bin/env node
/**
 * dataexp — parse Set\DATA.EXP, the game's master data table.
 *
 * DATA.EXP is XOR-0x22 text. Loader: CB.EXE 0x00446280 -> 0x00446380.
 * Field layout comes from the *consumers* of the table (base DAT_004af570,
 * record stride 0x38 = 56 bytes), which is authoritative:
 *
 *   +0x00  int   id
 *   +0x04  char  name[16]        ('$' in the file is replaced by ' ' on load)
 *   +0x14  int   HP              (read as int: `*(int*)(&DAT_004af584 + idx*0x38)`)
 *   +0x18  u8    f2
 *   +0x19  u8    f3
 *   +0x1a  u8    f4
 *   +0x1b  u8    f5
 *   +0x1c  u8    f6      <- 视野 (vision)  : 工人 = 4, matches the in-game panel
 *   +0x1d  u8    f7      <- 射程 (range)   : 工人 = 1, archers 6, siege 10
 *   +0x1e  u8    f8
 *   +0x1f  u8    f9
 *   +0x20  int   f10
 *   +0x24  int   f11     (resource costs: compared against 0x4b8cfc/00/04/08)
 *   +0x28  int   f12
 *   +0x2c  int   f13
 *   +0x30  int   f14
 *   +0x34  u8    f15     <- 防御力 (defence): 工人 = 1, matches the panel
 *   +0x35  u8    f16
 *
 * Sections (all integers are 4-byte `%d` in the loader's format strings):
 *   1) "%s %d %d %d"                    x29  officer ranks
 *   2) "%d %s %d ... (13)"              x27  buildings          (13 numeric fields)
 *   3) "%d %s %d ... (16)"              x26  unit types         (16 numeric fields)
 *   4) "%d %d %d %d %d %d %d %d"        x23  cost / upgrade table
 *   5) "%s %d %d %d %d %d"              x4 blocks   officers (name + 5)
 *
 * Usage: node dataexp.mjs [--set iso/SET] [--json out.json]
 */
import fs from 'node:fs';
import { readExpText } from './exptable.mjs';

function tokenize(text) {
  return text.split(/\s+/).filter(Boolean).map((t) => t.replace(/,+$/, ''));
}

export function parseDataExp(file) {
  const text = readExpText(file);
  const t = tokenize(text);
  let p = 0;
  const num = () => Number(t[p++]);
  const str = () => String(t[p++]).replace(/\$/g, ' ').replace(/\s+$/, '');
  const ints = (n) => { const a = []; for (let i = 0; i < n; i++) a.push(num()); return a; };

  // ---- 1. officer ranks: name + 3
  const rankCount = num();
  const ranks = [];
  for (let i = 0; i < rankCount; i++) { const name = str(); ranks.push({ name, v: ints(3) }); }

  // ---- 2. buildings: id + name + 13
  const buildingCount = num();
  const buildings = [];
  for (let i = 0; i < buildingCount; i++) { const id = num(); const name = str(); buildings.push({ id, name, v: ints(13) }); }

  // ---- 3. unit types: id + name + 16
  const unitCount = num();
  const units = [];
  for (let i = 0; i < unitCount; i++) { const id = num(); const name = str(); units.push({ id, name, v: ints(16) }); }
  // 原始文件缺陷修复：最后一行「旗舰」的 id 被误写成 48（与「水兵」重复），
  // 于是 52 缺失 —— 而 UNIT.EXP 里 id 52 是存在的，原型会因此拿不到属性。
  // 去重并把重复 id 顺延到下一个未占用的 id（48 → … → 52），保持文件顺序不变。
  {
    const seen = new Set();
    for (const u of units) {
      const orig = u.id;
      while (seen.has(u.id)) u.id += 1;
      seen.add(u.id);
      if (u.id !== orig) u.idRepairedFrom = orig;
    }
  }

  // ---- 4. cost / upgrade table: 8 ints
  const costCount = num();
  const costs = [];
  for (let i = 0; i < costCount; i++) costs.push(ints(8));

  // ---- 5. four officer blocks: count, then name + 5
  const officerBlocks = [];
  while (p < t.length) {
    const n = num();
    if (!Number.isFinite(n) || n <= 0) break;
    const list = [];
    for (let i = 0; i < n; i++) {
      if (p >= t.length) break;
      const name = str();
      list.push({ name, might: num(), intellect: num(), tier: num(), d: num(), e: num() });
    }
    officerBlocks.push(list);
  }

  return { rankCount, ranks, buildingCount, buildings, unitCount, units, costCount, costs, officerBlocks, leftover: t.length - p, text };
}

/** Map the 16 file numbers of a unit record onto the consumer-derived slot layout.
 *  2026-10-16 REA 定名：f2/f3=攻A/攻B(+0x18/+0x19)、f4/f5=防A/防B(+0x1A/+0x1B)、
 *  f10=石价(+0x20)、costA/B/C=金/木/粮价(+0x24/+0x28/+0x2C)、defence(旧名)=击杀经验(+0x34)、
 *  f16=士气恢复(+0x35)。（FUN_00425b50/FUN_004255c0/FUN_00422a20/FUN_00446380） */
export const UNIT_FIELDS = [
  { off: 0x14, name: 'hp', width: 4 },
  { off: 0x18, name: 'attack', width: 1 },
  { off: 0x19, name: 'attackB', width: 1 },
  { off: 0x1a, name: 'defenceA', width: 1 },
  { off: 0x1b, name: 'defenceB', width: 1 },
  { off: 0x1c, name: 'vision', width: 1 },
  { off: 0x1d, name: 'range', width: 1 },
  { off: 0x1e, name: 'f8', width: 1 },
  { off: 0x1f, name: 'f9', width: 1 },
  { off: 0x20, name: 'costStone', width: 4 },
  { off: 0x24, name: 'costGold', width: 4 },
  { off: 0x28, name: 'costWood', width: 4 },
  { off: 0x2c, name: 'costFood', width: 4 },
  { off: 0x30, name: 'f14', width: 4 },
  { off: 0x34, name: 'expGain', width: 1 },
  { off: 0x35, name: 'moraleGain', width: 1 },
];
// 2026-10-19 修正说明：本表 JSON 键名沿用旧口径（costStone/costGold/costWood/costFood），
// 但资源对应已按 UNIT-ATTRIBUTES §1.1 订正为 铁/粮/木/金：+0x24 实为「粮」（键名误作
// costGold）、+0x2C 实为「金」（键名误作 costFood）、+0x20 实为「铁」（键名 costStone 沿旧称）。
// 下游（gen_extra_sheets / godot_export / building_registry 及已生成的 chibi*.json /
// production_units.json）仍消费旧键名——改名须连同再生成数据一起做，属「工人造价金/粮
// 互换」重制侧裁决事项，暂不动；本工具的打印行已按铁/粮/木/金顺序输出。

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) {
  const argv = process.argv.slice(2);
  let set = 'iso/SET', json = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--set') set = argv[++i];
    else if (argv[i] === '--json') json = argv[++i];
  }
  const d = parseDataExp(`${set}/DATA.EXP`);
  console.log(`DATA.EXP: ${d.rankCount} ranks, ${d.buildingCount} buildings, ${d.unitCount} unit types, ` +
    `${d.costCount} cost rows, ${d.officerBlocks.length} officer blocks ` +
    `(${d.officerBlocks.map((b) => b.length).join('/')}), leftover tokens = ${d.leftover}`);
  console.log('\n--- 26 unit types (id, name, HP, vision, range, defence, costs) ---');
  for (const u of d.units) {
    const m = {};
    UNIT_FIELDS.forEach((f, i) => { m[f.name] = u.v[i]; });
    console.log(`  ${String(u.id).padStart(2)} ${u.name.padEnd(4)} HP=${String(m.hp).padStart(4)} 视野=${m.vision} 射程=${m.range} 防A=${m.defenceA}  cost=铁${String(m.costStone).padStart(4)} 粮${String(m.costGold).padStart(4)} 木${String(m.costWood).padStart(4)} 金${String(m.costFood).padStart(4)}`);
  }
  console.log('\n--- 27 buildings (id, name, HP) ---');
  console.log('  ' + d.buildings.map((b) => `${b.id}:${b.name}(${b.v[0]})`).join('  '));
  console.log('\n--- officers per block (top 3 by might each) ---');
  d.officerBlocks.forEach((blk, i) => {
    const top = [...blk].sort((a, b) => b.might - a.might).slice(0, 3).map((o) => `${o.name}(${o.might}/${o.intellect})`);
    console.log(`  block ${i}: ${blk.length} officers — ${top.join('  ')}`);
  });
  if (json) {
    fs.writeFileSync(json, JSON.stringify({
      units: d.units.map((u) => Object.fromEntries(UNIT_FIELDS.map((f, i) => [f.name, u.v[i]]).concat([['id', u.id], ['name', u.name]]))),
      buildings: d.buildings,
      ranks: d.ranks,
      costs: d.costs,
      officers: d.officerBlocks,
    }, null, 1));
    console.log(`\nwrote ${json}`);
  }
}
