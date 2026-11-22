#!/usr/bin/env node
/**
 * terrain_bake — bake a whole 三国赤壁 battlefield map into one image.
 *
 * Rendering model (all verified from CB.EXE via REA/Ghidra, 2026-10 session):
 *
 *  tile u16   = [15:12] class | [11:8] ground set | [7:4] sheet col | [3:0] sheet row
 *               (FUN_00459b50; 0xFFFF = empty cell, skipped by the renderer)
 *  ground set = record #i of Set\GROUND.EXP  ->  LIB.LWC frame #i is its sheet
 *               record fields: W=44, H=A, yOff=B (= H-22)
 *  sheet cell = source rect (col*44, row*H, 44, H) inside LIB frame #set
 *  screen     = x = 44*row + 22*(col & 1)     (FUN_00459c30)
 *               y = 11*col - (H_set - 22) - layerOffset[layer]
 *  layers     = drawn in order 0 (ground), 1 (cliffs / fences / trees), 2 (top decor)
 *  (FUN_0041db40 draws one cell; FUN_00459bd0 fetches from the layer arrays.)
 *
 * Exports bakeMap() for reuse (e.g. by tools/godot_export.mjs).
 *
 * Usage (from repo root):
 *   node tools/lib/terrain_bake.mjs <out.png> --map CHIBIC1 [--meds _work/iso/MEDS]
 *        [--bmp _work/iso/BMP] [--set _work/iso/SET] [--pal _work/iso/RES/BATTLE.PAL]
 *        [--layers 0,1,2] [--scale 1] [--crop x,y,w,h]
 */
import fs from 'node:fs';
import path from 'node:path';
import { parseMed } from './medmap.mjs';
import { readFrames, extractFrame, readPal } from './lwc2png.mjs';
import { readExpText } from './exptable.mjs';
import { writeRgbPng } from './lwc_sheet.mjs';

export const TILE_W = 44;

/** Parse Set\GROUND.EXP -> [{i, H, W, yOff, cols, rows, list, ...}] */
export function parseGroundExp(setDir) {
  const tokens = readExpText(`${setDir}/GROUND.EXP`).split(/\s+/).filter(Boolean).map((t) => t.replace(/,+$/, ''));
  const setCount = Number(tokens[0]);
  const ground = [];
  let p = 1;
  for (let i = 0; i < setCount; i++) {
    const a = Number(tokens[p++]), b = Number(tokens[p++]), c = Number(tokens[p++]);
    const idx = Number(tokens[p++]);
    const rect = [Number(tokens[p++]), Number(tokens[p++]), Number(tokens[p++]), Number(tokens[p++])];
    const W = Number(tokens[p++]), H = Number(tokens[p++]), yOff = Number(tokens[p++]);
    const cols = Number(tokens[p++]), rows = Number(tokens[p++]);
    const list = [];
    for (let k = 0; k < cols; k++) list.push(Number(tokens[p++]));
    ground.push({ i, abc: [a, b, c], idx, rect, W, H, yOff, cols, rows, list });
  }
  return ground;
}

/**
 * Bake a map to an RGB buffer.
 * @returns {{W:number, H:number, rgb:Buffer, stats:object}}
 */
export function bakeMap(o) {
  const opt = {
    map: 'CHIBIC1', meds: '_work/iso/MEDS', bmp: '_work/iso/BMP', set: '_work/iso/SET',
    pal: '_work/iso/RES/BATTLE.PAL', layers: '0,1,2', scale: 1, crop: null, quiet: true,
    ...o,
  };
  const ground = parseGroundExp(opt.set);
  const libFrames = readFrames(`${opt.bmp}/LIB.LWC`, `${opt.bmp}/LIB.IDX`);
  const sheets = libFrames.map((f) => (f.error ? null : { w: f.width, h: f.height, px: extractFrame(f) }));
  const pal = readPal(opt.pal);

  const m = parseMed(fs.readFileSync(path.join(opt.meds, `${opt.map}.MED`)));
  const rows = m.rows, cols = m.cols;
  const PADX = 88, PADY = 160;
  const W = TILE_W * rows + PADX, H = 11 * cols + PADY;
  const rgb = Buffer.alloc(W * H * 3);

  const stats = { drawn: 0, skipped: 0, setsUsed: new Map() };

  const drawTile = (lay, r, c) => {
    const t = m.layers[lay][r][c];
    if (t === 0xffff) { stats.skipped++; return; }
    const set = (t >> 8) & 0xf;
    const sCol = (t >> 4) & 0xf;
    const sRow = t & 0xf;
    const g = ground[set];
    if (!g) return;
    const sheet = sheets[g.idx];
    if (!sheet) return;
    const cw = g.W, ch = g.H;
    const sx0 = sCol * cw, sy0 = sRow * ch;
    if (sx0 + cw > sheet.w || sy0 + ch > sheet.h) return;
    const dx0 = TILE_W * r + (TILE_W >> 1) * (c & 1);
    const dy0 = 11 * c - (ch - 22);
    stats.drawn++;
    stats.setsUsed.set(set, (stats.setsUsed.get(set) || 0) + 1);
    for (let y = 0; y < ch; y++) {
      const dy = dy0 + y;
      if (dy < 0 || dy >= H) continue;
      let src = (sy0 + y) * sheet.w + sx0;
      let dst = (dy * W + dx0) * 3;
      for (let x = 0; x < cw; x++, src++, dst += 3) {
        const dx = dx0 + x;
        if (dx < 0 || dx >= W) continue;
        const v = sheet.px[src];
        if (v === 0) continue; // index 0 = transparent
        const col = pal[v];
        rgb[dst] = col[0]; rgb[dst + 1] = col[1]; rgb[dst + 2] = col[2];
      }
    }
  };

  for (const L of opt.layers.split(',').map(Number)) {
    for (let c = 0; c < cols; c++) for (let r = 0; r < rows; r++) drawTile(L, r, c);
  }

  // ------- 饰物叠加：OTHER.LWC 帧 7（树/粮堆）-------
  // 原版 FUN_00444960 / FUN_00444860：L0 高位类 ≠ F 的格子叠加 44×60 饰物子帧，
  // 相位 = (class & 3) * 2 + (class ∈ 8..0xB ? 1 : 0)。相位 0 = 松树（木）、2 = 粮堆（粮）。
  // 2026-10-16 用户实测：“地图里没有树木和粮草” = 这条链此前从未接上（文档标注“静态烘焙仍未叠加”）。
  if (opt.decor !== false) {
    let otherPx = null, otherW = 0, otherH = 0;
    try {
      const of = readFrames(`${opt.bmp}/OTHER.LWC`, `${opt.bmp}/OTHER.IDX`);
      const fr = of[7];
      if (fr && !fr.error) { otherPx = extractFrame(fr); otherW = fr.width; otherH = fr.height; }
    } catch (e) { otherPx = null; }
    if (otherPx) {
      const SUB_W = 44, SUB_H = 60;
      let decorDrawn = 0;
      for (let c = 0; c < cols; c++) {
        for (let r = 0; r < rows; r++) {
          const t0 = m.layers[0][r][c];
          if (t0 === 0xffff) continue;
          const cls = (t0 >> 12) & 0xf;
          if (cls === 0xf) continue;
          const phase = (cls & 3) * 2 + ((cls >= 8 && cls <= 0xb) ? 1 : 0);
          const sy0 = phase * SUB_H;
          if (sy0 + SUB_H > otherH || SUB_W > otherW) continue;
          const dx0 = TILE_W * r + (TILE_W >> 1) * (c & 1);
          const dy0 = 11 * c - (SUB_H - 22);
          decorDrawn++;
          for (let y = 0; y < SUB_H; y++) {
            const dy = dy0 + y;
            if (dy < 0 || dy >= H) continue;
            let src = (sy0 + y) * otherW;
            let dst = (dy * W + dx0) * 3;
            for (let x = 0; x < SUB_W; x++, src++, dst += 3) {
              const dx = dx0 + x;
              if (dx < 0 || dx >= W) continue;
              const v = otherPx[src];
              if (v === 0) continue;      // 索引 0 = 透明
              const col = pal[v];
              rgb[dst] = col[0]; rgb[dst + 1] = col[1]; rgb[dst + 2] = col[2];
            }
          }
        }
      }
      stats.decorDrawn = decorDrawn;
    }
  }

  // scale / crop
  if (opt.crop) {
    const [cx, cy, cw0, ch0] = opt.crop;
    const buf = Buffer.alloc(cw0 * ch0 * 3);
    for (let y = 0; y < ch0; y++) {
      const sy = cy + y;
      if (sy < 0 || sy >= H) continue;
      for (let x = 0; x < cw0; x++) {
        const sx = cx + x;
        if (sx < 0 || sx >= W) continue;
        const s = (sy * W + sx) * 3, d = (y * cw0 + x) * 3;
        buf[d] = rgb[s]; buf[d + 1] = rgb[s + 1]; buf[d + 2] = rgb[s + 2];
      }
    }
    return { W: cw0, H: ch0, rgb: buf, stats };
  }
  if (opt.scale !== 1) {
    const oW = Math.round(W * opt.scale), oH = Math.round(H * opt.scale);
    const buf = Buffer.alloc(oW * oH * 3);
    for (let y = 0; y < oH; y++) {
      const sy = Math.min(H - 1, Math.floor(y / opt.scale));
      for (let x = 0; x < oW; x++) {
        const sx = Math.min(W - 1, Math.floor(x / opt.scale));
        const s = (sy * W + sx) * 3, d = (y * oW + x) * 3;
        buf[d] = rgb[s]; buf[d + 1] = rgb[s + 1]; buf[d + 2] = rgb[s + 2];
      }
    }
    return { W: oW, H: oH, rgb: buf, stats };
  }
  return { W, H, rgb, stats };
}

// ---------------------------------------------------------------------- CLI
const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) {
  const argv = process.argv.slice(2);
  if (!argv.length || argv[0].startsWith('--')) {
    console.error('usage: node tools/lib/terrain_bake.mjs <out.png> --map CHIBIC1 [--meds ..] [--bmp ..] [--set ..] [--pal ..] [--layers 0,1,2] [--scale 1] [--crop x,y,w,h]');
    process.exit(2);
  }
  const o = {
    out: argv[0], map: 'CHIBIC1',
    meds: '_work/iso/MEDS', bmp: '_work/iso/BMP', set: '_work/iso/SET',
    pal: '_work/iso/RES/BATTLE.PAL', layers: '0,1,2', scale: 1, crop: null,
  };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--map') o.map = argv[++i];
    else if (a === '--meds') o.meds = argv[++i];
    else if (a === '--bmp') o.bmp = argv[++i];
    else if (a === '--set') o.set = argv[++i];
    else if (a === '--pal') o.pal = argv[++i];
    else if (a === '--layers') o.layers = argv[++i];
    else if (a === '--scale') o.scale = Number(argv[++i]);
    else if (a === '--crop') o.crop = argv[++i].split(',').map(Number);
    else throw new Error(`unknown option ${a}`);
  }
  const { W, H, rgb, stats } = bakeMap(o);
  fs.mkdirSync(path.dirname(path.resolve(o.out)), { recursive: true });
  writeRgbPng(o.out, W, H, rgb);
  console.log(`${o.map}: layers ${o.layers} -> ${o.out} (${W}x${H})`);
  console.log(`  tiles drawn: ${stats.drawn}, 0xFFFF skipped: ${stats.skipped}`);
  console.log('  sets used: ' + [...stats.setsUsed.entries()].sort((a, b) => a[0] - b[0]).map(([s, n]) => `set${s}:${n}`).join(' '));
}
