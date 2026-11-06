#!/usr/bin/env node
/**
 * water_grid_patch — 给 data/*.json 补 `waterWalkable`（水军寻路层），并可导出棋盘图核对。
 *
 * 用法（工作区根目录）：
 *   node tools/water_grid_patch.mjs                # 逐个 MED 写回 data/<map>.json（保留其它字段）
 *   node tools/water_grid_patch.mjs --dry          # 只统计，不写文件
 *   node tools/water_grid_patch.mjs --png chibic13 # 另存 _work/water/chibic13-water.png
 *
 * 该字段与 `terrainWalkable` 同长（rows*cols，行主序），1 = 可通航水面。
 * 真正的导出管线在 tools/godot_export.mjs 里也会写这个字段（两者用同一个 waterCells）。
 */
import fs from 'node:fs';
import path from 'node:path';
import { parseMed } from './lib/medmap.mjs';
import { waterCells, waterStats } from './lib/water_grid.mjs';
import { writeRgbPng } from './lib/lwc_sheet.mjs';

const args = process.argv.slice(2);
const dry = args.includes('--dry');
const restoreLand = args.includes('--restore-land');
const pngIdx = args.indexOf('--png');
const pngMap = pngIdx >= 0 ? String(args[pngIdx + 1] || '').toLowerCase() : '';
const dataDir = path.join('godot', 'chibi_remake', 'data');
const medDir = path.join('_work', 'iso', 'MEDS');
const int = (v) => Number(v) | 0;
if (!fs.existsSync(medDir)) {
  console.error(`missing ${medDir}`);
  process.exit(1);
}
fs.mkdirSync(path.join('_work', 'water'), { recursive: true });

const files = fs.readdirSync(medDir).filter((f) => f.toLowerCase().endsWith('.med')).sort();
let patched = 0;
for (const f of files) {
  const map = path.basename(f, path.extname(f)).toLowerCase();
  const buf = fs.readFileSync(path.join(medDir, f));
  const mm = parseMed(buf);
  const cells = waterCells(mm);
  const st = waterStats(mm, cells);
  console.log(`${map.padEnd(10)} water=${String(st.water).padStart(6)} shore=${String(st.shore).padStart(5)}`);
  if (pngMap && map === pngMap) {
    const W = mm.rows * 4;
    const H = mm.cols * 4;
    const rgb = new Uint8Array(W * H * 3);
    for (let a = 0; a < mm.rows; a++) {
      for (let b = 0; b < mm.cols; b++) {
        const i = a * mm.cols + b;
        const t0 = mm.layers[0][a][b];
        const cls = t0 === 0xffff ? -1 : (t0 >> 12) & 0xf;
        let c = [24, 24, 24];
        if (cls >= 0) c = [90, 90, 90];
        if (cls === 0xf || cls === 8 || cls === 9) c = [40, 90, 40];
        if (cells[i]) c = [40, 90, 200];
        for (let dy = 0; dy < 4; dy++) {
          for (let dx = 0; dx < 4; dx++) {
            const px = ((b * 4 + dy) * W + (a * 4 + dx)) * 3;
            rgb[px] = c[0]; rgb[px + 1] = c[1]; rgb[px + 2] = c[2];
          }
        }
      }
    }
    const outPng = path.join('_work', 'water', `${map}-water.png`);
    writeRgbPng(outPng, W, H, rgb);
    console.log(`  mask → ${outPng}`);
  }
  const dataPath = path.join(dataDir, `${map}.json`);
  if (!fs.existsSync(dataPath)) continue;
  if (dry) continue;
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  data.waterWalkable = Array.from(cells);
  if (restoreLand) {
    // 撤掉"水面从陆军通行表剔除"的实验性改动：按原规则恢复
    //   terrainWalkable = class ∈ {0xf,8,9} 且 layer1/2 为空（水面磁贴 class 仍是 0xf）
    //   walkable        = 同一底线，但静态建筑（unit ≤ 26）所在格 = 0
    const blockedByBuilding = new Set((data.objects || [])
      .filter((o) => int(o.unit) <= 26)
      .map((o) => int(o.A) * int(data.cols) + int(o.B)));
    const land = data.terrainWalkable.slice();
    const place = data.walkable.slice();
    for (let a = 0; a < mm.rows; a++) {
      for (let b = 0; b < mm.cols; b++) {
        const i = a * mm.cols + b;
        if (!cells[i]) continue;
        const cls = (mm.layers[0][a][b] >> 12) & 0xf;
        const passable = cls === 0xf || cls === 8 || cls === 9;
        land[i] = passable ? 1 : 0;
        place[i] = passable && !blockedByBuilding.has(i) ? 1 : 0;
      }
    }
    data.terrainWalkable = land;
    data.walkable = place;
  }
  fs.writeFileSync(dataPath, JSON.stringify(data));
  patched++;
}
console.log(dry ? 'dry run: nothing written' : `patched ${patched} data files with waterWalkable`);
