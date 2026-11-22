/**
 * savformat — model and codec for 三国赤壁 (1997, WayAhead) save files (.SAV / .GEN).
 *
 * Derived from CB.EXE:
 *   GAME_Save        @ 0x0042c640   writes a .SAV
 *   GAME_Load        @ 0x0042ca60   reads a .SAV
 *   GAME_GetSaveInfo @ 0x0042cf60   reads a .GEN (save-slot metadata)
 *   GAME_SetGenInfo  @ 0x0042d750   writes a .GEN
 *   FUN_004559d0 / FUN_00455a60     the block writer / reader used by .SAV
 */
import fs from 'node:fs';

const GBK = new TextDecoder('gbk');

/* ------------------------------------------------------------------ .SAV --- */

/**
 * A .SAV is a sequence of *compressed blocks*. Every block is written by
 * FUN_004559d0 as:
 *
 *     uint32_le  originalSize          // uncompressed byte count
 *     then a byte stream that expands to exactly originalSize bytes:
 *       - a non-zero byte            -> emit that byte
 *       - 0x00 followed by 4 bytes   -> emit that many zero bytes
 *
 * The reader validates originalSize, so the format is self-checking.
 */

/** Blocks in write order, with the uncompressed size each one must expand to. */
export const BLOCK_ORDER = [
  { name: 'name1', kind: 'name', note: 'save name: 1-byte length + GBK bytes, uncompressed' },
  { name: 'worldA', size: 0x5be48, source: '0x004b7f20', note: 'main world state; contains the CB.SET paths "meds\\", "Set\\", "Bmp\\", "avi\\", "sound\\"' },
  { name: 'worldB', size: 0x1d89c, source: '0x00524a20' },
  { name: 'worldC', size: 0x26b0, source: '0x004ade00' },
  { name: 'flag0', size: 4, source: '0x00484bc0' },
  { name: 'worldD', size: 0x3070, source: '0x005165e0' },
  { name: 'worldE', size: 0x28a0, source: '0x004b4e50' },
  { name: 'flag1', size: 4, source: '0x0048342c' },
  { name: 'worldF', size: 0x800, source: '0x004b76f0' },
  { name: 'name2', kind: 'name' },
  { name: 'name3', kind: 'name' },
  { name: 'unitsA', size: 0x15180, source: '0x00581740' },
  { name: 'unitsB', size: 0xa8c0, source: '0x0051a160' },
  { name: 'unitsC', size: 0x15180, source: '0x005968c0' },
  { name: 'unitsD', size: 0x3f480, source: '0x005422c0' },
  { name: 'unitsE', size: 140000, source: '0x005afb20' },
  { name: 'viewX', size: 4, note: 'camera X' },
  { name: 'viewY', size: 4, note: 'camera Y' },
  { name: 'viewExtra', size: 0x88, source: '0x005164a0' },
  { name: 'const1', size: 4, source: '0x00482584' },
  { name: 'const2', size: 4, source: '0x00482588' },
  { name: 'taskState', size: 0xc, source: '0x004b7f10' },
  { name: 'const3', size: 4, source: '0x00485318' },
  { name: 'systemTime', size: 0x30, source: '0x00513e70', note: 'two SYSTEMTIME structs' },
  { name: 'tailA', size: 0x154, source: '0x00487838' },
  { name: 'tailB', size: 4, source: '0x004830e0' },
  { name: 'tailC', size: 4, source: '0x004830e4' },
  { name: 'tailD', size: 4, source: '0x004830e8' },
  { name: 'tailE', size: 2, source: '0x004830ec' },
  { name: 'tailF', size: 4, source: '0x004830f0' },
];

/** Decode one FUN_004559d0 block; returns { size, data, consumed } or { error }. */
export function readBlock(buf, off) {
  if (off + 4 > buf.length) return { error: 'no size prefix', consumed: 0 };
  const size = buf.readUInt32LE(off);
  let p = off + 4;
  const out = Buffer.alloc(size);
  let o = 0;
  while (o < size) {
    if (p >= buf.length) return { error: `stream ended at ${p}, produced ${o}/${size}`, consumed: p - off, size };
    const b = buf[p];
    if (b !== 0) { out[o++] = b; p++; continue; }
    if (p + 5 > buf.length) return { error: 'truncated zero-run', consumed: p - off, size };
    const run = buf.readUInt32LE(p + 1);
    if (run === 0) return { error: `zero-length zero-run at ${p}`, consumed: p - off, size };
    o += Math.min(run, size - o); // Buffer.alloc is already zero-filled
    p += 5;
  }
  return { size, data: out, consumed: p - off, off };
}

/** Encode one block exactly as FUN_004559d0 does. */
export function writeBlock(data) {
  const head = Buffer.alloc(4);
  head.writeUInt32LE(data.length, 0);
  const parts = [head];
  let i = 0;
  while (i < data.length) {
    if (data[i] !== 0) { parts.push(data.subarray(i, i + 1)); i++; continue; }
    let j = i;
    while (j + 1 < data.length && data[j + 1] === 0) j++;
    const t = Buffer.alloc(5);
    t.writeUInt32LE(j - i + 1, 1);
    parts.push(t);
    i = j + 1;
  }
  return Buffer.concat(parts);
}

/** Parse a whole .SAV. */
export function parseSav(buf) {
  const out = { blocks: [], names: [], errors: [], ok: false };
  let off = 0;

  for (const spec of BLOCK_ORDER) {
    if (spec.kind === 'name') {
      const direct = readBlock(buf, off);
      let rec = null;
      if (!direct.error && direct.size > 0 && direct.size < 256) {
        const text = GBK.decode(direct.data);
        if (!/\ufffd/.test(text)) rec = { name: spec.name, kind: 'name', offset: off, size: direct.size, data: direct.data, text, consumed: direct.consumed };
      }
      if (!rec) {
        const len = buf[off];
        if (len > 0 && off + 1 + len <= buf.length) {
          const data = Buffer.from(buf.subarray(off + 1, off + 1 + len));
          rec = { name: spec.name, kind: 'name', offset: off, size: len, data, text: GBK.decode(data), consumed: 1 + len, raw: true };
        }
      }
      if (!rec) { out.errors.push(`cannot read ${spec.name} at ${off}`); break; }
      out.blocks.push(rec);
      if (rec.text.trim()) out.names.push(rec);
      off += rec.consumed;
      continue;
    }
    const r = readBlock(buf, off);
    if (r.error) { out.errors.push(`${spec.name}: ${r.error}`); break; }
    if (r.size !== spec.size) out.errors.push(`${spec.name}: size prefix says ${r.size}, model expects ${spec.size}`);
    let nz = 0; for (const b of r.data) if (b) nz++;
    out.blocks.push({ ...spec, kind: 'state', offset: off, stored: r.consumed, data: r.data, nonZero: nz, fill: nz / r.size });
    off += r.consumed;
  }

  out.consumed = off;
  out.total = buf.length;
  out.remainder = buf.length - off;
  out.ok = out.errors.length === 0 && out.remainder === 0;
  if (out.remainder !== 0) out.errors.push(`unconsumed ${out.remainder} byte(s) at ${off}`);
  return out;
}

/* ------------------------------------------------------------------ .GEN --- */

/**
 * A .GEN holds one save slot's metadata. GAME_GetSaveInfo @ 0x0042cf60 reads a
 * slot as `fread(&len,1,1); fread(dst,len,1); dst[len]=0;` and
 * GAME_SetGenInfo @ 0x0042d750 writes one byte plus four bytes per record.
 *
 * The slot stride is 45 bytes (590 = 13*45 + 5 trailing bytes). The payload is
 * not always text: in the shipped saves most slots carry small numeric fields
 * separated by zero padding, and some carry the 8-bit name strings that also
 * appear in the .SAV header. Field-level semantics remain open.
 */
export function parseGen(buf, recordSize = 45) {
  const count = Math.floor(buf.length / recordSize);
  const rows = [];
  for (let i = 0; i < count; i++) {
    const off = i * recordSize;
    const len = buf[off];
    const raw = Buffer.from(buf.subarray(off + 1, Math.min(off + 1 + len, buf.length)));
    const decoded = len > 0 ? GBK.decode(raw) : '';
    rows.push({ index: i, offset: off, len, raw, text: /\ufffd/.test(decoded) ? '' : decoded });
  }
  return { rows, recordSize, count, total: buf.length, remainder: buf.length - count * recordSize };
}

/* ------------------------------------------------------------------- CLI --- */

if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('savformat.mjs')) {
  const files = process.argv.slice(2);
  if (!files.length) {
    console.log('usage: savformat.mjs <file.SAV|file.GEN> ...');
    console.log('exports: readBlock, writeBlock, parseSav, parseGen, BLOCK_ORDER');
    process.exit(0);
  }
  for (const f of files) {
    const buf = fs.readFileSync(f);

    if (/\.gen$/i.test(f)) {
      const g = parseGen(buf);
      console.log(`\n=== ${f}  (${buf.length} bytes)  .GEN meta: ${g.count} slots x ${g.recordSize}B, trailing ${g.remainder}B ===`);
      console.log('   idx  offset  len  payload');
      for (const r of g.rows) {
        const hex = [...r.raw.subarray(0, 8)].map((x) => x.toString(16).padStart(2, '0')).join(' ');
        const shown = r.text ? JSON.stringify(r.text) : `[${hex}${r.raw.length > 8 ? ' ...' : ''}]`;
        console.log(`  ${String(r.index).padStart(4)} ${String(r.offset).padStart(7)} ${String(r.len).padStart(4)}  ${shown}`);
      }
      continue;
    }

    const r = parseSav(buf);
    console.log(`\n=== ${f}  (${buf.length} bytes)  ${r.ok ? 'OK - every block decoded, file fully consumed' : 'MISMATCH'} ===`);
    r.errors.slice(0, 8).forEach((e) => console.log('  ! ' + e));
    console.log('  block             offset    stored   expanded   fill   detail');
    for (const b of r.blocks) {
      const detail = b.kind === 'name'
        ? `name(${b.size}B) ${JSON.stringify(b.text)}`
        : `${(b.fill * 100).toFixed(1).padStart(5)}%${b.note ? '  // ' + b.note : ''}`;
      console.log(`  ${b.name.padEnd(16)} ${String(b.offset).padStart(8)} ${String(b.stored ?? b.consumed).padStart(9)} ${String(b.size).padStart(10)}   ${detail}`);
    }
    console.log(`  consumed=${r.consumed} total=${r.total} remainder=${r.remainder}`);
  }
}
