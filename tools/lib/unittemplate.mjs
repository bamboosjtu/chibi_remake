#!/usr/bin/env node
/**
 * unittemplate — 从存档中提取运行时"单位类型模板表"（0x5268F4 起、0x26C 字节/条）。
 *
 * 证据：GAME0.SAV 的第 2 号数据块覆盖内存 [0x524A20, 0x5422BC)，其中包含
 * 单位模板表；字段对照（2026-10 REA 会话）：
 *   +0x00  u32  W（像素宽，等于 UNIT.EXP 的 W）
 *   +0x04  u32  H
 *   +0x08  u32  分组/类别（2/3/5/7…，语义待定）
 *   +0x0C  u32  动画行数（= UNIT.EXP 的 rows）
 *   +0x10  u32  兵种 id（= UNIT.EXP 的 id）
 *   +0x14  u8   类（tail 规则：==2 → 尾4；∈{3,7,8,10,11} → 尾2；见 medobjects.mjs）
 *   +0x18  u32  ?（0/1/2）
 *   +0x11C 行数×u32 动画槽位表：值 = id*1024 + 序号 k（行 → 动画号映射）
 *   +0x228 起 名称/路径字符串区
 *
 * 用法：node tools/lib/unittemplate.mjs [GAME0.SAV] [out.json]
 */
import fs from 'node:fs';
import path from 'node:path';
import { parseSav } from './savformat.mjs';

const savPath = process.argv[2] || '_work/saves/GAME0.SAV';
const outPath = process.argv[3] || '_work/dec/units_template.json';

const r = parseSav(fs.readFileSync(savPath));
const block = r.blocks.find((x) => x.name === 'worldB');
if (!block) { console.error('worldB block not found'); process.exit(1); }
const bytes = block.data;
const BASE = 0x5268F4 - 0x524A20;
const S = 0x26C;

const units = [];
for (let u = 0; u < 53; u++) {
  const o = BASE + u * S;
  if (o + S > bytes.length) break;
  const W = bytes.readUInt32LE(o);
  const H = bytes.readUInt32LE(o + 4);
  if (W === 0 || W > 512 || H > 512) continue;
  const grp = bytes.readUInt32LE(o + 8);
  const rows = bytes.readUInt32LE(o + 12);
  const id = bytes.readUInt32LE(o + 16);
  const cls = bytes[o + 0x14];
  const f18 = bytes.readUInt32LE(o + 0x18);
  const anim = [];
  for (let k = 0; k < Math.min(rows, 64); k++) {
    anim.push(bytes.readUInt32LE(o + 0x11C + k * 4));
  }
  units.push({ slot: u, id, W, H, grp, rows, cls, f18, anim });
}

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(units, null, 1));
console.log(`extracted ${units.length} unit templates -> ${outPath}`);
for (const t of units.slice(0, 12)) {
  console.log(`  slot ${String(t.slot).padStart(2)} id=${String(t.id).padStart(2)} ${t.W}x${t.H} rows=${String(t.rows).padStart(2)} cls=${t.cls} grp=${t.grp} anim0..3=${t.anim.slice(0, 4).join(',')}`);
}
const clsHist = {};
for (const t of units) clsHist[t.cls] = (clsHist[t.cls] || 0) + 1;
console.log('class histogram:', JSON.stringify(clsHist));
