#!/usr/bin/env node
/**
 * unitexport — export UNIT.LWC into named, per-unit animation folders using
 * Set\Unit.exp as the unit registry.
 *
 * Usage:
 *   node unitexport.mjs <outDir> [--pal f.pal] [--team n] [--dir <bmp dir>] [--list]
 *
 * Output layout:
 *   <outDir>/<id>_<name>/frame_000.png ...
 *
 * Palette indices are preserved verbatim, so the shared team-colour band
 * (0x4B..0x55) survives as ordinary indices in the PNG and can be recoloured
 * later by shifting them, exactly as CB.EXE 0x00455cb0 does.
 */
import fs from 'node:fs';
import path from 'node:path';
import { parseUnitExp } from './exptable.mjs';
import { loadBank, decodeFrame } from './unitdec.mjs';
import { readPal } from './lwc2png.mjs';
import { writePng } from './unit2png.mjs';

const argv = process.argv.slice(2);
if (!argv.length) {
  console.error('usage: unitexport.mjs <outDir> [--pal f.pal] [--team n] [--dir <bmp dir>] [--set <set dir>] [--list]');
  process.exit(2);
}
const o = { outDir: argv[0], pal: null, team: 0, dir: 'iso/BMP', set: 'iso/SET', list: false };
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--pal') o.pal = argv[++i];
  else if (a === '--team') o.team = Number(argv[++i]);
  else if (a === '--dir') o.dir = argv[++i];
  else if (a === '--set') o.set = argv[++i];
  else if (a === '--list') o.list = true;
  else throw new Error(`unknown option ${a}`);
}

const registry = parseUnitExp(`${o.set}/UNIT.EXP`);
const bank = loadBank(`${o.dir}/UNIT.LWC`, `${o.dir}/UNIT.IDX`);
const atlasFrames = bank.idx.length;
const palette = o.pal ? readPal(o.pal) : null;

if (o.list) {
  console.log(`id  name    size      frames  range          folder`);
  for (const u of registry.units) {
    const last = u.firstFrame + u.frameCount - 1;
    const oob = last >= atlasFrames ? '  <-- BEYOND ATLAS (alias?)' : '';
    console.log(`${String(u.id).padStart(2)}  ${u.name.padEnd(7)} ${(u.width + 'x' + u.height).padEnd(9)} ${String(u.frameCount).padStart(6)}  ${String(u.firstFrame).padStart(4)}..${String(last).padEnd(5)} ${String(u.id).padStart(2)}_${u.name}${oob}`);
  }
  const real = registry.units.filter((u) => u.firstFrame + u.frameCount <= atlasFrames);
  console.log(`\n${registry.count} records; ${real.length} fully inside the atlas (${atlasFrames} frames); ${real.reduce((s, u) => s + u.frameCount, 0)} frames covered`);
  process.exit(0);
}

fs.mkdirSync(o.outDir, { recursive: true });
let dirs = 0, files = 0, skipped = 0;
for (const u of registry.units) {
  const last = u.firstFrame + u.frameCount - 1;
  if (last >= atlasFrames) { skipped++; console.log(`skip unit ${u.id} ${u.name}: frames ${u.firstFrame}..${last} exceed the atlas`); continue; }
  const d = path.join(o.outDir, `${String(u.id).padStart(2, '0')}_${u.name}`);
  fs.mkdirSync(d, { recursive: true });
  dirs++;
  for (let k = 0; k < u.frameCount; k++) {
    const idx = u.firstFrame + k;
    const f = decodeFrame(bank, idx, { teamOffset: o.team });
    writePng(path.join(d, `frame_${String(k).padStart(3, '0')}.png`), f.w, f.h, f.px, palette);
    files++;
  }
}
console.log(`wrote ${files} PNG in ${dirs} unit folders to ${o.outDir}${palette ? ' (palettised, index 0 transparent)' : ''}${o.team ? ` team+${o.team}` : ''}${skipped ? `, skipped ${skipped} unit(s)` : ''}`);
