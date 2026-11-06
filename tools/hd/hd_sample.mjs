#!/usr/bin/env node
/**
 * hd_sample — AI 超分（Real-ESRGAN ncnn-vulkan）试产/对比工具。
 *
 * 用法（仓库根目录）：
 *   node tools/hd/hd_sample.mjs prep                  # 栅格化代表性素材 -> _work/hd/sample/in/
 *   node tools/hd/hd_sample.mjs montage               # 生成三栏对比图 -> _work/hd/sample/cmp_*.png
 *
 * 超分本体用 _tools\realesrgan\realesrgan-ncnn-vulkan.exe（见 docs/17-art.md「超分管线」）：
 *   realesrgan-ncnn-vulkan.exe -i <in> -o <out_anime> -n realesrgan-x4plus-anime -s 4 -f png
 *   realesrgan-ncnn-vulkan.exe -i <in> -o <out_x4>    -n realesrgan-x4plus       -s 4 -f png
 */
import fs from 'node:fs';
import path from 'node:path';
import { loadBank, decodeFrame } from '../lib/unitdec.mjs';
import { writePng } from '../lib/unit2png.mjs';
import { readFrames, extractFrame, readPal } from '../lib/lwc2png.mjs';
import { parseUnitExp } from '../lib/exptable.mjs';
import { readPng } from '../lib/pngread.mjs';
import { writeRgbPng } from '../lib/lwc_sheet.mjs';

const ROOT = process.cwd();
const BMP = path.join(ROOT, '_work/iso/BMP');
const RES = path.join(ROOT, '_work/iso/RES');
const SET = path.join(ROOT, '_work/iso/SET');
const HD = path.join(ROOT, '_work/hd/sample');
const IN = path.join(HD, 'in');

const cmd = process.argv[2] || 'prep';

function prep() {
  fs.rmSync(IN, { recursive: true, force: true });
  fs.mkdirSync(IN, { recursive: true });
  const pal = readPal(path.join(RES, 'BATTLE.PAL'));

  // ---- UNIT 精灵（透明底, 队伍色偏移 0）----
  const reg = parseUnitExp(path.join(SET, 'UNIT.EXP'));
  const bank = loadBank(path.join(BMP, 'UNIT.LWC'), path.join(BMP, 'UNIT.IDX'));
  const pick = [[30, [0, 1, 2, 3, 4, 5, 6, 7]], [22, [0]], [45, [0]], [1, [0]], [38, [0]], [25, [0]]];
  for (const [uid, frames] of pick) {
    const rec = reg.units.find((x) => x.id === uid);
    for (const k of frames) {
      const f = decodeFrame(bank, rec.firstFrame + k, { teamOffset: 0 });
      writePng(path.join(IN, `unit_${String(uid).padStart(3, '0')}_f${String(k).padStart(2, '0')}.png`), f.w, f.h, f.px, pal);
    }
  }

  // ---- LIB 地形图集 ----
  const lib = readFrames(path.join(BMP, 'LIB.LWC'), path.join(BMP, 'LIB.IDX'));
  for (const i of [0, 2, 7]) {
    const f = lib[i];
    writePng(path.join(IN, `lib_${String(i).padStart(4, '0')}.png`), f.width, f.height, extractFrame(f), pal);
  }

  // ---- BMP UI / 标题 ----
  const bmp = readFrames(path.join(BMP, 'BMP.LWC'), path.join(BMP, 'BMP.IDX'));
  for (const i of [54, 42]) {
    const f = bmp[i];
    writePng(path.join(IN, `bmp_${String(i).padStart(4, '0')}.png`), f.width, f.height, extractFrame(f), pal);
  }

  console.log(`prepped ${fs.readdirSync(IN).length} files -> ${IN}`);
}

function loadRGB(p) {
  const d = readPng(p);
  return d; // {w,h,rgb}
}

function nearest4(src) {
  const { w, h, rgb } = src;
  const out = Buffer.alloc(w * 4 * h * 4 * 3);
  for (let y = 0; y < h * 4; y++) {
    for (let x = 0; x < w * 4; x++) {
      const s = ((y >> 2) * w + (x >> 2)) * 3;
      const d = (y * w * 4 + x) * 3;
      out[d] = rgb[s]; out[d + 1] = rgb[s + 1]; out[d + 2] = rgb[s + 2];
    }
  }
  return { w: w * 4, h: h * 4, rgb: out };
}

function scaleRGB(src, k) {
  const w = Math.max(1, Math.round(src.w * k));
  const h = Math.max(1, Math.round(src.h * k));
  const out = Buffer.alloc(w * h * 3);
  for (let y = 0; y < h; y++) {
    const sy = Math.min(src.h - 1, Math.floor(y / k));
    for (let x = 0; x < w; x++) {
      const sx = Math.min(src.w - 1, Math.floor(x / k));
      const s = (sy * src.w + sx) * 3, d = (y * w + x) * 3;
      out[d] = src.rgb[s]; out[d + 1] = src.rgb[s + 1]; out[d + 2] = src.rgb[s + 2];
    }
  }
  return { w, h, rgb: out };
}

function blit(canvas, cw, src, x0, y0) {
  for (let y = 0; y < src.h; y++) {
    if (y0 + y >= canvas.h) break;
    const s = y * src.w * 3;
    const d = ((y0 + y) * cw + x0) * 3;
    src.rgb.copy(canvas.rgb, d, s, s + src.w * 3);
  }
}

/** 3 栏对比图（nearest×4 | anime×4 | x4plus×4），每栏按宽度上限缩放 */
function montageRow(files, colCap, outName) {
  const cols = 3;
  const cells = [];
  for (const f of files) {
    const a = loadRGB(path.join(HD, 'out_anime', f));
    const b = loadRGB(path.join(HD, 'out_x4', f));
    const n = nearest4(loadRGB(path.join(IN, f)));
    cells.push([n, a, b]);
  }
  const scaled = cells.map((row) => row.map((c) => scaleRGB(c, Math.min(1, colCap / c.w))));
  const colW = scaled[0].map((c) => c.w);
  const rowH = scaled.map((row) => Math.max(...row.map((c) => c.h)));
  const W = colW[0] + colW[1] + colW[2];
  const H = rowH.reduce((a, b) => a + b, 0);
  const canvas = { w: W, h: H, rgb: Buffer.alloc(W * H * 3) };
  let y = 0;
  for (let r = 0; r < scaled.length; r++) {
    let x = 0;
    for (let c = 0; c < cols; c++) {
      blit(canvas, W, scaled[r][c], x, y);
      x += colW[c];
    }
    y += rowH[r];
  }
  writeRgbPng(path.join(HD, outName), W, H, canvas.rgb);
  console.log(`montage -> ${outName} (${W}x${H})  [nearest | anime | x4plus]`);
}

function montage() {
  montageRow(['unit_030_f00.png', 'unit_022_f00.png', 'unit_045_f00.png', 'unit_001_f00.png'], 420, 'cmp_units.png');
  montageRow(['lib_0002.png', 'lib_0007.png', 'bmp_0042.png'], 620, 'cmp_sheets.png');
  console.log('done');
}

if (cmd === 'prep') prep();
else if (cmd === 'montage') montage();
else { console.log('usage: node tools/hd/hd_sample.mjs prep|montage'); process.exit(2); }
