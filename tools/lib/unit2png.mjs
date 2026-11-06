#!/usr/bin/env node
/**
 * unit2png — extract UNIT.LWC (三国赤壁, 1997) unit sprites to PNG.
 *
 * The frame format is taken from CB.EXE 0x00455cb0 (the unit blitter) and is
 * verified against all 2708 frames: every decoded row sums to exactly `width`,
 * and the declared stream length accounts for the whole frame span.
 *
 *   +0   u16 width
 *   +2   u16 0
 *   +4   u16 height
 *   +6   u16 0
 *   +8   u16 magic 0xE6C2
 *   +10  u32 dataSize        (= streamBytes + 4)
 *   +14  records of (u16 x, u16 run)
 *          run == 0 -> end the row (cursor is already at column `width`)
 *          run >  0 -> advance the cursor right by `x`, copy `run` literal bytes
 *
 * Palette indices 0x4B..0x55 are the team-colour ramp: the blitter adds a
 * per-player offset to them, so `--team N` reproduces an owner's colouring.
 *
 * Usage:
 *   node unit2png.mjs <outDir> [--pal f.pal] [--team n] [--from a] [--to b]
 *                              [--index a,b,c] [--list]
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { loadBank, frameCount, decodeFrame, HEADER_SIZE, TEAM_LO, TEAM_HI } from './unitdec.mjs';
import { readPal } from './lwc2png.mjs';

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
/** 8-bit palette PNG; index 0 is written fully transparent (the sprites' background). */
function writePng(file, w, h, idx, palette) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 3; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const raw = Buffer.alloc(h * (w + 1));
  for (let y = 0; y < h; y++) {
    raw[y * (w + 1)] = 0;
    idx.copy(raw, y * (w + 1) + 1, y * w, y * w + w);
  }
  const plte = Buffer.alloc(256 * 3);
  for (let i = 0; i < 256; i++) {
    const c = palette ? palette[i] : [i, i, i];
    plte[i * 3] = c[0]; plte[i * 3 + 1] = c[1]; plte[i * 3 + 2] = c[2];
  }
  const trns = Buffer.alloc(1); trns[0] = 0; // only index 0 transparent
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('PLTE', plte), chunk('tRNS', trns),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]));
}

export { writePng };

function main() {
  const argv = process.argv.slice(2);
  if (!argv.length) {
    console.error('usage: unit2png.mjs <outDir> [--pal f.pal] [--team n] [--from a] [--to b] [--index a,b] [--list]');
    process.exit(2);
  }
  const o = { outDir: argv[0], pal: null, team: 0, from: 0, to: null, index: null, list: false, dir: 'iso/BMP' };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--pal') o.pal = argv[++i];
    else if (a === '--team') o.team = Number(argv[++i]);
    else if (a === '--from') o.from = Number(argv[++i]);
    else if (a === '--to') o.to = Number(argv[++i]);
    else if (a === '--index') o.index = argv[++i].split(',').map(Number);
    else if (a === '--list') o.list = true;
    else if (a === '--dir') o.dir = argv[++i];
    else throw new Error(`unknown option ${a}`);
  }

  const bank = loadBank(`${o.dir}/UNIT.LWC`, `${o.dir}/UNIT.IDX`);
  const n = frameCount(bank);
  const palette = o.pal ? readPal(o.pal) : null;

  if (o.list) {
    console.log(`UNIT.LWC: ${n} frames`);
    console.log('  idx range      size     count');
    const sizes = [];
    for (let i = 0; i < n; i++) sizes.push(`${decodeFrame(bank, i).w}x${decodeFrame(bank, i).h}`);
    let s = 0;
    for (let i = 1; i <= n; i++) {
      if (i === n || sizes[i] !== sizes[s]) {
        console.log(`  ${String(s).padStart(5)}-${String(i - 1).padEnd(6)} ${sizes[s].padEnd(9)} ${i - s}`);
        s = i;
      }
    }
    return;
  }

  const list = o.index ?? (() => {
    const out = [];
    for (let i = o.from; i <= Math.min(o.to ?? n - 1, n - 1); i++) out.push(i);
    return out;
  })();

  fs.mkdirSync(o.outDir, { recursive: true });
  let written = 0;
  for (const i of list) {
    const f = decodeFrame(bank, i, { teamOffset: o.team });
    const name = `unit_${String(i).padStart(4, '0')}_${f.w}x${f.h}.png`;
    writePng(path.join(o.outDir, name), f.w, f.h, f.px, palette);
    written++;
  }
  console.log(`wrote ${written} PNG to ${o.outDir}${palette ? ' (palettised, index 0 transparent)' : ' (greyscale)'}${o.team ? ` team+${o.team}` : ''}`);
}

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) main();
