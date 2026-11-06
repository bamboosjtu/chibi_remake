#!/usr/bin/env node
/**
 * hd_split — 把大图切成 2x2 四块（供 Godot 纹理分块加载）。
 * 用法: node tools/hd/hd_split.mjs <in.png> <outPrefix>
 *   例如: node tools/hd/hd_split.mjs x4.png _work/hd/terrain4/chibic1  -> chibic1_q0..q3.png
 */
import fs from 'node:fs';
import path from 'node:path';
import { readPng } from '../lib/pngread.mjs';
import { writeRgbPng } from '../lib/lwc_sheet.mjs';

const [inp, prefix] = process.argv.slice(2);
if (!inp || !prefix) {
  console.error('usage: node tools/hd/hd_split.mjs <in.png> <outPrefix>');
  process.exit(2);
}
const d = readPng(inp);
const W = d.w, H = d.h, hw = W >> 1, hh = H >> 1;
fs.mkdirSync(path.dirname(path.resolve(prefix)), { recursive: true });
for (let q = 0; q < 4; q++) {
  const qx = q % 2, qy = (q / 2) | 0;
  const buf = Buffer.alloc(hw * hh * 3);
  for (let y = 0; y < hh; y++) {
    const s = ((qy * hh + y) * W + qx * hw) * 3;
    d.rgb.copy(buf, y * hw * 3, s, s + hw * 3);
  }
  writeRgbPng(`${prefix}_q${q}.png`, hw, hh, buf);
}
console.log(`split ${inp} (${W}x${H}) -> ${prefix}_q0..3.png (${hw}x${hh} each)`);
