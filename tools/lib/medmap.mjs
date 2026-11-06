#!/usr/bin/env node
/**
 * medmap — parse and validate 赤壁's MEDS\*.MED battlefield maps.
 *
 * Layout, from CB.EXE 0x0042bd70 (GAME_ReadMedFile):
 *
 *   +0              u32   version           (must be >= 100; older files are rejected)
 *   +4              u8    nameLen
 *   +5              char[nameLen]  GBK map name (NUL terminated after load)
 *   +5+nameLen      u32   cols              -> DAT_00524a38
 *   +9+nameLen      u32   rows              -> DAT_00524a3c
 *   +13+nameLen     5 x u32                 (20 bytes, read into a local)
 *   then 3 background layers. Each layer is `cols` columns of `rows` u16 tile ids:
 *       for (c = 0; c < cols; c++) fread(dst, rows * 2, 1, fp);
 *       dst advances by 0x780 bytes (720) per column, i.e. the in-memory column
 *       stride is a fixed 360 u16 while only `rows` of them come from the file.
 *   then 5 x 8 bytes
 *   then 5 object sections: u16 count, then per entry:
 *       u8 used; if used: u16 type, u16 x, u16 y, u32 extra, then a
 *       state-dependent tail (see docs/10-battlefield.md).
 *
 * Usage: node medmap.mjs [--dir iso/MEDS] [--detail] [--png out.png]
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { writeRgbPng } from './lwc_sheet.mjs';

const LAYERS = 3;
const COL_STRIDE_BYTES = 720; // 0xb4 dwords, the in-memory stride
const MEM_LAYER_BYTES = 86400; // 0x5460 dwords

export function parseMed(buf) {
  const version = buf.readUInt32LE(0);
  const nameLen = buf.readUInt8(4);
  const nameBytes = buf.subarray(5, 5 + nameLen);
  let name;
  try { name = new TextDecoder('gbk').decode(nameBytes); } catch { name = nameBytes.toString('latin1'); }
  const rows = buf.readUInt32LE(5 + nameLen); // outer loop count = rows in the layer
  const cols = buf.readUInt32LE(9 + nameLen); // u16 per row   = row width in tiles
  const extra = [];
  for (let i = 0; i < 5; i++) extra.push(buf.readUInt32LE(13 + nameLen + i * 4));

  let p = 33 + nameLen;
  const layers = [];
  for (let L = 0; L < LAYERS; L++) {
    const rowsArr = [];
    for (let r = 0; r < rows; r++) {
      const row = new Uint16Array(cols);
      for (let c = 0; c < cols; c++) row[c] = buf.readUInt16LE(p + c * 2);
      rowsArr.push(row);
      p += cols * 2; // the file packs each row tightly
    }
    layers.push(rowsArr);
  }
  const afterLayers = p;
  const table5 = [];
  for (let i = 0; i < 5; i++) {
    table5.push({ a: buf.readUInt32LE(p), b: buf.readUInt32LE(p + 4) });
    p += 8;
  }
  const afterTable5 = p;
  const sections = [];
  for (let s = 0; s < 5; s++) {
    if (p + 2 > buf.length) { sections.push({ count: null, entries: [], truncated: true }); continue; }
    const count = buf.readUInt16LE(p); p += 2;
    const entries = [];
    for (let i = 0; i < count && p < buf.length; i++) {
      const used = buf.readUInt8(p); p += 1;
      if (!used) { entries.push({ used: 0 }); continue; }
      if (p + 10 > buf.length) break;
      const type = buf.readUInt16LE(p);
      const x = buf.readUInt16LE(p + 2);
      const y = buf.readUInt16LE(p + 4);
      const extra32 = buf.readUInt32LE(p + 6);
      p += 10;
      entries.push({ used, type, x, y, extra32 });
      // tail is state-dependent in the original; record where we stopped
      break; // stop this section: tail length is not statically known
    }
    sections.push({ count, entries, stoppedAt: p });
  }
  return { version, nameLen, name, cols, rows, extra, layers, headerEnd: 33 + nameLen, afterLayers, table5, afterTable5, sections, total: buf.length };
}

function main() {
  const argv = process.argv.slice(2);
  const o = { dir: 'iso/MEDS', detail: false, png: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--dir') o.dir = argv[++i];
    else if (argv[i] === '--detail') o.detail = true;
    else if (argv[i] === '--png') o.png = argv[++i];
  }

  const files = fs.readdirSync(o.dir).filter((n) => /\.med$/i.test(n)).sort();
  console.log('file            size    ver  name          cols rows  hdrEnd  layersEnd  +40   tail');
  let ok = 0;
  for (const f of files) {
    const buf = fs.readFileSync(path.join(o.dir, f));
    const m = parseMed(buf);
    const layerBytes = LAYERS * m.cols * m.rows * 2;
    const expectEnd = m.headerEnd + layerBytes;
    const fits = expectEnd + 40 <= buf.length;
    if (fits) ok++;
    console.log(
      `${f.padEnd(15)} ${String(buf.length).padStart(7)} ${String(m.version).padStart(4)}  ${m.name.padEnd(12)} ${String(m.cols).padStart(4)} ${String(m.rows).padStart(4)}  ${String(m.headerEnd).padStart(6)}  ${String(m.afterLayers).padStart(9)}  ${String(m.afterTable5 - m.afterLayers).padStart(3)}  ${String(buf.length - m.afterTable5).padStart(6)}  ${fits ? '' : '<-- DOES NOT FIT'}`);
    if (o.detail) {
      console.log(`   extra5 = ${m.extra.join(', ')}`);
      console.log(`   table5 = ${m.table5.map((t) => `${t.a}:${t.b}`).join('  ')}`);
      console.log(`   sections: ${m.sections.map((s) => s.count).join(', ')}`);
    }
  }
  console.log(`\n${ok}/${files.length} maps fit the header + 3 x cols x rows x 2 layout`);

  if (o.png) {
    const buf = fs.readFileSync(path.join(o.dir, files[0]));
    const m = parseMed(buf);
    renderLayer(m, o.png);
  }
}

/** Colour-map layer 0 tile ids so the map's regions are visible. */
function renderLayer(m, out) {
  const W = m.cols, H = m.rows;
  const ids = new Set();
  for (const row of m.layers[0]) for (const v of row) ids.add(v);
  const list = [...ids].sort((a, b) => a - b);
  const palette = new Map();
  list.forEach((id, i) => {
    const h = (i * 47) % 360, s = 0.55, l = id === 0 ? 0.12 : 0.25 + 0.5 * ((i % 5) / 4);
    palette.set(id, hsl(h, s, l));
  });
  const rgb = Buffer.alloc(W * H * 3);
  for (let r = 0; r < m.rows; r++) {
    for (let c = 0; c < m.cols; c++) {
      const id = m.layers[0][r][c];
      const col = palette.get(id) || [255, 0, 255];
      const k = (r * W + c) * 3;
      rgb[k] = col[0]; rgb[k + 1] = col[1]; rgb[k + 2] = col[2];
    }
  }
  writeRgbPng(out, W, H, rgb);
  console.log(`\nrendered layer 0 -> ${out}  ${W}x${H}  distinct tile ids: ${list.length}`);
  console.log(`  ids: ${list.slice(0, 48).join(',')}${list.length > 48 ? ' ...' : ''}`);
}
function hsl(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), mm = l - c / 2;
  let r = 0, g = 0, b = 0;
  if (h < 60) [r, g, b] = [c, x, 0]; else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x]; else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c]; else [r, g, b] = [c, 0, x];
  return [Math.round((r + mm) * 255), Math.round((g + mm) * 255), Math.round((b + mm) * 255)];
}

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) main();
