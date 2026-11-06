#!/usr/bin/env node
/**
 * lwc_sheet — pack selected frames from a .LWC bank into one contact-sheet PNG.
 *
 * Row-major packing: each row of the sheet holds up to `cols` frames and is as
 * tall as the tallest frame in that row. Frames keep their native pixel size
 * (use --scale to zoom). The stdout report lists the frame index drawn in each
 * cell, in reading order, so cells can be identified without a font.
 *
 * Usage:
 *   node lwc_sheet.mjs <bank.LWC> <bank.IDX> <out.png> [options]
 * Options:
 *   --pal <f.pal>     palette for colour output
 *   --from <n>        first frame index (default 0)
 *   --to <n>          last frame index, inclusive
 *   --index a,b,c     explicit frame list (overrides --from/--to)
 *   --cols <n>        columns per sheet row (default 8)
 *   --scale <n>       integer zoom (default 1)
 *   --minarea <n>     skip frames smaller than this
 *   --maxarea <n>     skip frames larger than this
 *   --bg <rrggbb>     background colour (default 202020)
 *   --grid            draw a 1px separator between cells
 */
import fs from 'node:fs';
import zlib from 'node:zlib';
import { readFrames, extractFrame, readPal, rowSize } from './lwc2png.mjs';

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const td = Buffer.concat([Buffer.from(type, 'latin1'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, crc]);
}
export function writeRgbPng(file, width, height, rgb) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = width * 3;
  const raw = Buffer.alloc(height * (stride + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    rgb.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

export function writeRgbaPng(file, width, height, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = width * 4;
  const raw = Buffer.alloc(height * (stride + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    rgba.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

function parseArgs(argv) {
  const o = {
    lwc: argv[0], idx: argv[1], out: argv[2],
    pal: null, from: 0, to: null, index: null,
    cols: 8, scale: 1, minarea: 0, maxarea: Infinity, bg: 0x202020, grid: false,
  };
  for (let i = 3; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--pal') o.pal = argv[++i];
    else if (a === '--from') o.from = Number(argv[++i]);
    else if (a === '--to') o.to = Number(argv[++i]);
    else if (a === '--index') o.index = argv[++i].split(',').map(Number);
    else if (a === '--cols') o.cols = Number(argv[++i]);
    else if (a === '--scale') o.scale = Number(argv[++i]);
    else if (a === '--minarea') o.minarea = Number(argv[++i]);
    else if (a === '--maxarea') o.maxarea = Number(argv[++i]);
    else if (a === '--bg') o.bg = parseInt(argv[++i], 16);
    else if (a === '--grid') o.grid = true;
    else throw new Error(`unknown option ${a}`);
  }
  return o;
}

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (!o.lwc || !o.idx || !o.out) {
    console.error('usage: lwc_sheet.mjs <bank.LWC> <bank.IDX> <out.png> [--pal f] [--from n] [--to n] [--index a,b] [--cols n] [--scale n]');
    process.exit(2);
  }
  const all = readFrames(o.lwc, o.idx);
  const pal = o.pal ? readPal(o.pal) : null;
  const bgR = (o.bg >> 16) & 255, bgG = (o.bg >> 8) & 255, bgB = o.bg & 255;

  let sel = o.index ? o.index.map((i) => all[i]).filter(Boolean)
    : all.filter((f) => f.i >= o.from && f.i <= (o.to ?? all.length - 1));
  sel = sel.filter((f) => {
    const a = f.width * f.height;
    return f.width > 0 && f.height > 0 && a >= o.minarea && a <= o.maxarea;
  });
  if (!sel.length) { console.error('no frames selected'); process.exit(1); }

  // ---- layout: row-major, row height = tallest frame in that row.
  // All extents are in OUTPUT pixels, so apply the zoom factor here.
  const sc = Math.max(1, o.scale);
  const cols = Math.max(1, o.cols);
  const rows = [];
  for (let i = 0; i < sel.length; i += cols) {
    const r = sel.slice(i, i + cols);
    rows.push({
      frames: r,
      h: Math.max(...r.map((f) => f.height)) * sc,
      w: r.reduce((s, f) => s + f.width * sc, 0),
    });
  }
  const pad = o.grid ? 1 : 0;
  const W = Math.max(...rows.map((r) => r.w + pad * (r.frames.length + 1)));
  const H = rows.reduce((s, r) => s + r.h + pad, 0) + pad;
  const rgb = Buffer.alloc(W * H * 3);
  for (let i = 0; i < W * H; i++) { rgb[i * 3] = bgR; rgb[i * 3 + 1] = bgG; rgb[i * 3 + 2] = bgB; }

  const placed = [];
  let cy = pad;
  for (const r of rows) {
    let cx = pad;
    for (const f of r.frames) {
      const px = extractFrame(f);
      for (let y = 0; y < f.height; y++) {
        for (let x = 0; x < f.width; x++) {
          const vi = px[y * f.width + x];
          let R, G, B;
          if (pal) { const c = pal[vi]; R = c[0]; G = c[1]; B = c[2]; }
          else { R = vi; G = vi; B = vi; }
          for (let sy = 0; sy < sc; sy++) {
            for (let sx = 0; sx < sc; sx++) {
              const ox = (cx + x * sc + sx), oy = (cy + y * sc + sy);
              if (ox >= W || oy >= H) continue;
              const k = (oy * W + ox) * 3;
              rgb[k] = R; rgb[k + 1] = G; rgb[k + 2] = B;
            }
          }
        }
      }
      placed.push({ i: f.i, w: f.width, h: f.height, x: cx, y: cy });
      cx += f.width * sc + pad;
    }
    cy += r.h + pad;
  }
  writeRgbPng(o.out, W, H, rgb);
  console.log(`${o.out}  ${W}x${H}  ${sel.length} frames, ${cols} cols, scale ${sc}${pal ? ', palettised' : ', greyscale'}`);
  console.log('cell order (reading order):');
  for (let i = 0; i < placed.length; i += cols) {
    console.log('  ' + placed.slice(i, i + cols).map((p) => `#${p.i}(${p.w}x${p.h})`).join(' '));
  }
}

// Run the CLI only when this file is the process entry point (safe to import).
const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) main();
