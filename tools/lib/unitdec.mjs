// UNIT.LWC decoder — verified against CB.EXE 0x00455cb0 (the unit sprite blitter).
//
// Frame header is 14 bytes, not 16:
//   +0   u16 width
//   +2   u16 0
//   +4   u16 height
//   +6   u16 0
//   +8   u16 magic 0xE6C2
//   +10  u32 dataSize      (= streamBytes + 4)
//
// The pixel stream starts at +14 and is a sequence of 4-byte records:
//   (u16 x, u16 run)
//     run == 0  -> end of row (cursor already sits at column `width`)
//     run >  0  -> advance the cursor right by `x`, then copy `run` literal bytes
//
// The blitter advances a destination pointer, so `x` is a *relative* step, and the
// runs of one row must sum to exactly `width`.
//
// Team recolour (from FUN_00455cb0): a literal byte c with 0x4A < c < 0x56 is
// written as c + playerOffset. Palette indices 0x4B..0x55 are the team-colour ramp.
//
// Frame offsets come from the sibling .IDX (u32 LE table, monotonically increasing).

import fs from 'node:fs';

export const MAGIC = 0xe6c2;
export const HEADER_SIZE = 14;
export const TEAM_LO = 0x4b; // 0x4A < c
export const TEAM_HI = 0x55; // c < 0x56

export function readIdx(idxBuf) {
  const n = Math.floor(idxBuf.length / 4);
  const off = new Array(n);
  for (let i = 0; i < n; i++) off[i] = idxBuf.readUInt32LE(i * 4);
  return off;
}

export function loadBank(lwcPath, idxPath) {
  const lwc = fs.readFileSync(lwcPath);
  const idx = readIdx(fs.readFileSync(idxPath));
  return { lwc, idx, lwcPath, idxPath };
}

export function frameCount(bank) {
  return bank.idx.length;
}

export function frameEnd(bank, i) {
  return i + 1 < bank.idx.length ? bank.idx[i + 1] : bank.lwc.length;
}

/**
 * Decode one frame.
 * @param {object} bank        result of loadBank()
 * @param {number} i           frame index
 * @param {object} [opts]
 * @param {number} [opts.teamOffset=0]  added to palette indices 0x4B..0x55 (mod 256)
 * @returns {{w:number,h:number,px:Buffer,teamOffset:number,
 *            headerW:number,headerH:number,dataSize:number,records:number,
 *            literals:number,bytesUsed:number,rowPixelCounts:number[]}}
 */
export function decodeFrame(bank, i, opts = {}) {
  const teamOffset = opts.teamOffset | 0;
  const start = bank.idx[i];
  const end = frameEnd(bank, i);
  const b = bank.lwc;

  const w = b.readUInt16LE(start + 0);
  const h = b.readUInt16LE(start + 4);
  const magic = b.readUInt16LE(start + 8);
  const dataSize = b.readUInt32LE(start + 10);
  if (magic !== MAGIC) throw new Error(`frame ${i}: bad magic 0x${magic.toString(16)} at 0x${start.toString(16)}`);
  if (w === 0 || h === 0) throw new Error(`frame ${i}: zero dimension ${w}x${h}`);

  const px = Buffer.alloc(w * h);
  const rowPixelCounts = new Array(h).fill(0);

  let p = start + HEADER_SIZE; // byte cursor in the stream
  let remaining = dataSize - 4; // mirrors the blitter's counter
  let row = 0;
  let col = 0;
  let records = 0;
  let literals = 0;

  // The blitter loops while `remaining >= 0`; bound the loop by the frame span too,
  // so a malformed counter can never read past the next frame.
  while (remaining >= 0 && row < h) {
    if (p + 4 > end) throw new Error(`frame ${i}: record past frame end (row ${row})`);
    const x = b.readUInt16LE(p);
    const run = b.readUInt16LE(p + 2);
    p += 4;
    remaining -= 4;
    records++;

    // The blitter advances the destination cursor by `x` unconditionally,
    // then either ends the row (run == 0) or writes `run` literal bytes.
    col += x;
    if (run === 0) {
      if (col !== w) throw new Error(`frame ${i}: row ${row} ended at column ${col}, expected ${w}`);
      rowPixelCounts[row] = col;
      row++;
      col = 0;
      if (row >= h) break;
    } else {
      if (col + run > w) throw new Error(`frame ${i}: row ${row} overruns (${col}+${run} > ${w})`);
      if (p + run > end) throw new Error(`frame ${i}: literals past frame end (row ${row})`);
      const base = row * w + col;
      for (let k = 0; k < run; k++) {
        let c = b[p + k];
        if (c > 0x4a && c < 0x56) c = (c + teamOffset) & 0xff;
        px[base + k] = c;
      }
      p += run;
      remaining -= run;
      col += run;
      literals += run;
    }
  }

  return {
    w, h, px, teamOffset,
    dataSize, records, literals,
    bytesUsed: p - (start + HEADER_SIZE),
    streamBytes: dataSize,
    spanBytes: end - start,
    rowPixelCounts,
  };
}
