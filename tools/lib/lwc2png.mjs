#!/usr/bin/env node
/**
 * lwc2png — converter prototype for 三国赤壁 (1997, WayAhead) bitmap banks.
 *
 * Verified format (from CB.EXE 0x0044a0a0, see docs/17-art.md):
 *   .IDX : uint32 little-endian offset table, one entry per frame, relative to .LWC start.
 *   .LWC : per frame, at the recorded offset:
 *            uint32 width
 *            uint32 height
 *            uint32 reserved      (observed 0xE6C2 in the low 16 bits; unused by the reader)
 *            uint32 reserved      (ignored)
 *            then `height` rows of `width` bytes, stored 8-bit palette indices.
 *          Each stored row is padded up to a 4-byte boundary:
 *              if (width & 3) != 0  ->  rowSize = (width & ~3) + 4     // == ((width>>2)+1)*4
 *              else                 ->  rowSize = width
 *          (CB.EXE computes exactly this; the padding bytes are skipped on load.)
 *
 * The game reads `width*height` bytes but walks the buffer with `rowSize`,
 * so the stored frame occupies rowSize*height bytes after the 16-byte header.
 *
 * Usage:
 *   node lwc2png.mjs <bank.LWC> <bank.IDX> <outDir> [options]
 * Options:
 *   --pal <file>      use a .pal file (1024-byte VGA DAC triples, 6-bit scaled)
 *   --index <n>       convert only frame n (repeatable)
 *   --list            only print the frame table
 *   --report          print full per-frame validation table
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

// ---------------------------------------------------------------- PNG writer
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
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const td = Buffer.concat([Buffer.from(type, 'latin1'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, crc]);
}
/** Write an 8-bit palette PNG (colour type 3). */
function writePng(file, width, height, indices, palette) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 3; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

  const raw = Buffer.alloc(height * (width + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (width + 1)] = 0; // filter: none
    indices.copy(raw, y * (width + 1) + 1, y * width, y * width + width);
  }
  const plte = Buffer.alloc(256 * 3);
  for (let i = 0; i < 256; i++) {
    const c = palette ? palette[i] : [i, i, i];
    plte[i * 3] = c[0]; plte[i * 3 + 1] = c[1]; plte[i * 3 + 2] = c[2];
  }
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', ihdr),
    pngChunk('PLTE', plte),
    pngChunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]));
}

// ---------------------------------------------------------------- format core
export const MAGIC = 0xe6c2;

/** Row size as computed by CB.EXE 0x0044a0ee..0x0044a105. */
export function rowSize(width) {
  return (width & 3) !== 0 ? (width & 0xfffffffc) + 4 : width;
}

/** Load a .IDX offset table. */
export function readIdx(idxPath) {
  const b = fs.readFileSync(idxPath);
  const n = b.length >> 2;
  const offsets = new Array(n);
  for (let i = 0; i < n; i++) offsets[i] = b.readUInt32LE(i * 4);
  return offsets;
}

/** Describe every frame; validates the size model against the next offset (or EOF). */
export function readFrames(lwcPath, idxPath) {
  const lwc = fs.readFileSync(lwcPath);
  const offsets = readIdx(idxPath);
  const frames = [];
  for (let i = 0; i < offsets.length; i++) {
    const start = offsets[i];
    const next = i + 1 < offsets.length ? offsets[i + 1] : lwc.length;
    if (start + 16 > lwc.length) {
      frames.push({ i, start, next, error: 'offset beyond EOF' });
      continue;
    }
    const width = lwc.readUInt32LE(start);
    const height = lwc.readUInt32LE(start + 4);
    const reserved1 = lwc.readUInt32LE(start + 8);
    const reserved2 = lwc.readUInt32LE(start + 12);
    const rs = rowSize(width);
    const expected = 16 + rs * height;
    frames.push({
      i, start, next, width, height, reserved1, reserved2,
      rowSize: rs, expected, stored: next - start,
      magicOk: (reserved1 & 0xffff) === MAGIC,
      sizeOk: expected === next - start,
      tightOk: 16 + width * height === next - start,
      lwc, dataOffset: start + 16,
    });
  }
  return frames;
}

/** Extract one frame's pixels, returning a tightly packed width*height index buffer. */
export function extractFrame(frame) {
  const { lwc, dataOffset, width, height, rowSize: rs } = frame;
  if (rs === width) {
    return Buffer.from(lwc.subarray(dataOffset, dataOffset + width * height));
  }
  const out = Buffer.alloc(width * height);
  for (let y = 0; y < height; y++) {
    lwc.copy(out, y * width, dataOffset + y * rs, dataOffset + y * rs + width);
  }
  return out;
}

// .PAL files are 1024 bytes = 256 entries of (R, G, B, 0), already 8-bit values.
// A 768-byte file is treated as 256 packed (R, G, B) triples.
export function readPal(palPath, order = 'rgb') {
  const b = fs.readFileSync(palPath);
  const quad = b.length >= 1024;
  const stride = quad ? 4 : 3;
  const pal = [];
  for (let i = 0; i < 256; i++) {
    const o = i * stride;
    let r = b[o], g = b[o + 1], bl = b[o + 2];
    if (order === 'bgr') [r, bl] = [bl, r];
    pal.push([r, g, bl]);
  }
  return pal;
}

// ---------------------------------------------------------------------- CLI
function main() {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error('usage: lwc2png.mjs <bank.LWC> <bank.IDX> <outDir> [--pal f.pal] [--index n]... [--list] [--report]');
    process.exit(2);
  }
  const [lwcPath, idxPath, outDir] = args;
  const opts = { pal: null, indices: [], list: false, report: false };
  for (let i = 3; i < args.length; i++) {
    if (args[i] === '--pal') opts.pal = args[++i];
    else if (args[i] === '--index') opts.indices.push(Number(args[++i]));
    else if (args[i] === '--list') opts.list = true;
    else if (args[i] === '--report') opts.report = true;
  }

  const name = path.basename(lwcPath).replace(/\.lwc$/i, '');
  const frames = readFrames(lwcPath, idxPath);
  const palette = opts.pal ? readPal(opts.pal) : null;

  const ok = frames.filter((f) => f.sizeOk).length;
  let loose = 0, tight = 0;
  for (const f of frames) { if (!f.sizeOk) { if (f.tightOk) tight++; else loose++; } }
  console.log(`${name}: ${frames.length} frames | size-model exact=${ok} tight=${tight} unexplained=${loose}`);

  if (opts.report) {
    console.log('   idx   offset     stored  w     h     rows   expected  magic  verdict');
    for (const f of frames) {
      const v = f.sizeOk ? 'exact' : f.tightOk ? 'tight' : 'UNEXPLAINED';
      console.log(`  ${String(f.i).padStart(4)}  ${String(f.start).padStart(8)} ${String(f.stored).padStart(7)}  ${String(f.width).padStart(4)}  ${String(f.height).padStart(4)}  ${String(f.rowSize).padStart(5)}  ${String(f.expected).padStart(8)}  ${f.magicOk ? 'ok ' : 'BAD'}    ${v}`);
    }
  } else if (opts.list) {
    for (const f of frames) console.log(`  #${f.i} @${f.start} ${f.width}x${f.height} row=${f.rowSize} stored=${f.stored} ${f.sizeOk ? '' : '(size off)'}`);
  }

  if (opts.indices.length === 0 && !opts.list && !opts.report) {
    fs.mkdirSync(outDir, { recursive: true });
    let written = 0;
    for (const f of frames) {
      if (!f.sizeOk && !f.tightOk) continue;
      if (f.width === 0 || f.height === 0) continue;
      const px = extractFrame(f);
      const file = path.join(outDir, `${name}_${String(f.i).padStart(4, '0')}_${f.width}x${f.height}.png`);
      writePng(file, f.width, f.height, px, palette);
      written++;
    }
    console.log(`  wrote ${written} PNG${palette ? ' (palettised)' : ' (greyscale: no --pal given)'} to ${outDir}`);
    return;
  }

  if (opts.indices.length) {
    fs.mkdirSync(outDir, { recursive: true });
    for (const i of opts.indices) {
      const f = frames[i];
      if (!f) { console.error(`  #${i}: no such frame`); continue; }
      const px = extractFrame(f);
      const file = path.join(outDir, `${name}_${String(i).padStart(4, '0')}_${f.width}x${f.height}.png`);
      writePng(file, f.width, f.height, px, palette);
      console.log(`  #${i} -> ${file}`);
    }
  }
}

// Run the CLI only when this file is the process entry point (safe under `node -e`).
const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) main();
