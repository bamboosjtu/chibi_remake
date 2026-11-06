#!/usr/bin/env node
/**
 * animsheet — render UNIT.LWC animation slots as a contact sheet, grouped by clip.
 *
 * Rows are animation slots in slot order (which is the order the engine indexes:
 * slot = clipBase + direction).  Within a row the frames are drawn in playback
 * order, so a row *is* one clip+direction sequence as ANISEQ01 defines it.
 * The coloured bar on the left marks the clip the slot belongs to (legend is
 * printed to stdout), so the picture can be compared with the arithmetic table.
 *
 * usage: node tools/hd/animsheet.mjs --id 30 [--out _work/sheets/unit30.png]
 *                                 [--pal <bank>/RES/BATTLE.PAL] [--dir iso/BMP] [--team n]
 */
import fs from 'node:fs';
import path from 'node:path';
import { loadBank, decodeFrame } from '../lib/unitdec.mjs';
import { writePng } from '../lib/unit2png.mjs';
import { readPal } from '../lib/lwc2png.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');

const CLIP_COLORS = {
  turn: [255, 64, 64],
  die: [64, 128, 255],
  walk: [64, 220, 64],
  act1: [255, 220, 64],
  act2: [255, 96, 255],
  act3: [64, 255, 255],
  unused: [140, 140, 140],
};

function parseArgs() {
  const a = process.argv.slice(2);
  const o = { id: null, out: null, pal: null, dir: 'iso/BMP', team: 0, clips: '_work/dec/anim_clips.json', only: null, scale: 1 };
  for (let i = 0; i < a.length; i++) {
    if (a[i] === '--id') o.id = Number(a[++i]);
    else if (a[i] === '--out') o.out = a[++i];
    else if (a[i] === '--pal') o.pal = a[++i];
    else if (a[i] === '--dir') o.dir = a[++i];
    else if (a[i] === '--team') o.team = Number(a[++i]);
    else if (a[i] === '--clip') o.only = a[++i];
    else if (a[i] === '--unused') o.only = 'unused';
    else if (a[i] === '--scale') o.scale = Math.max(1, Number(a[++i]) | 0);
    else throw new Error('unknown option ' + a[i]);
  }
  if (o.id == null) throw new Error('--id required');
  return o;
}

const o = parseArgs();
const table = JSON.parse(fs.readFileSync(path.join(ROOT, o.clips), 'utf8'));
const unit = table.units.find((u) => u.id === o.id);
if (!unit) throw new Error(`unit ${o.id} not in clip table`);

// slot -> clip name (first clip that claims it, in clip priority order)
const slotClip = new Map();
const order = ['turn', 'die', 'walk', 'act1', 'act2', 'act3'];
for (const name of order) {
  const cl = unit.clips[name];
  if (!cl) continue;
  for (const d of cl.dirs) if (!slotClip.has(d.slot)) slotClip.set(d.slot, name);
}
for (const s of unit.unassignedSlots) if (!slotClip.has(s.slot)) slotClip.set(s.slot, 'unused');

// slot -> frame list (playback order)
const slotFrames = new Map();
for (const name of order) {
  const cl = unit.clips[name];
  if (!cl) continue;
  for (const d of cl.dirs) if (!slotFrames.has(d.slot)) slotFrames.set(d.slot, d.framesRel);
}
for (const s of unit.unassignedSlots) if (!slotFrames.has(s.slot)) slotFrames.set(s.slot, s.framesRel);
// With --clip, render that clip's own slots even when it shares an art block with an
// earlier clip in the priority order (e.g. walk == turn for the ships).
if (o.only === 'unused') {
  // frames of this unit's block that no slot references (label cards / unused art)
  const used = new Set();
  for (const [, fr] of slotFrames) for (const f of fr) used.add(f);
  slotFrames.clear();
  const rest = [];
  for (let f = 0; f < unit.count; f++) if (!used.has(f)) rest.push(f);
  slotFrames.set(-1, rest);
  slotClip.set(-1, 'unused');
} else if (o.only) {
  const cl = unit.clips[o.only];
  if (!cl) throw new Error(`unit ${o.id} has no clip ${o.only}`);
  slotFrames.clear();
  for (const d of cl.dirs) { slotFrames.set(d.slot, d.framesRel); slotClip.set(d.slot, o.only); }
}

const bank = loadBank(path.join(ROOT, o.dir, 'UNIT.LWC'), path.join(ROOT, o.dir, 'UNIT.IDX'));
const palette = o.pal ? readPal(path.join(ROOT, o.pal)) : null;

const W = unit.W, H = unit.H, BAR = 6, GAP = 2;
const maxFrames = Math.max(...[...slotFrames.values()].map((f) => f.length));
let slots = [...slotFrames.keys()].sort((a, b) => a - b);
if (o.only) slots = slots.filter((s) => slotClip.get(s) === o.only);
if (!slots.length) throw new Error(`no slots for clip ${o.only}`);
const cols = maxFrames;
const SC = o.scale;
const width = (BAR + GAP + cols * (W + GAP)) * SC;
const height = (slots.length * (H + GAP) + GAP) * SC;

const canvas = Buffer.alloc(width * height); // palette index 0 = transparent background
// clip colour bars come from the palette too: we steal high indices to create flat colours
// (the sprite palette is 256 entries; we append our marker colours into unused slots).
const pal = palette ? palette.map((c) => [...c]) : Array.from({ length: 256 }, (_, i) => [i, i, i]);
for (const idx of [249, 250, 251, 252, 253, 254, 255]) pal[idx] = [0, 0, 0];
const markerIndex = { turn: 250, idle: 251, walk: 252, act1: 253, act2: 254, act3: 255, unused: 249 };
for (const [k, rgb] of Object.entries(CLIP_COLORS)) pal[markerIndex[k]] = rgb;

let y = GAP * SC;
const legend = [];
const put = (px, py, v) => {
  for (let dy = 0; dy < SC; dy++) for (let dx = 0; dx < SC; dx++) canvas[(py * SC + dy) * width + px * SC + dx] = v;
};
for (const s of slots) {
  const clip = slotClip.get(s) ?? 'unused';
  const bar = markerIndex[clip];
  for (let yy = y; yy < y + H * SC; yy++) for (let xx = GAP * SC; xx < (GAP + BAR) * SC; xx++) canvas[yy * width + xx] = bar;
  const frames = slotFrames.get(s);
  frames.forEach((f, i) => {
    const img = decodeFrame(bank, unit.atlasBase + f, { teamOffset: o.team });
    const x0 = GAP + BAR + GAP + i * (W + GAP);
    for (let yy = 0; yy < img.h && yy < H; yy++) {
      for (let xx = 0; xx < img.w && xx < W; xx++) {
        const v = img.px[yy * img.w + xx];
        if (v !== 0) put(x0 + xx, y / SC + yy, v);
      }
    }
  });
  legend.push(`row ${String(s).padStart(2)}  clip=${clip.padEnd(6)} frames(abs)=[${frames.map((f) => f + unit.atlasBase).join(',')}]`);
  y += (H + GAP) * SC;
}

const outPath = o.out ?? path.join(ROOT, '_work/sheets', `unit${String(o.id).padStart(2, '0')}_byclip.png`);
fs.mkdirSync(path.dirname(outPath), { recursive: true });
writePng(outPath, width, height, canvas, pal);
console.log(`unit ${unit.id} ${unit.sprite} ${unit.logical} ${W}x${H} cols=${unit.cols} rows=${unit.rows} frames=${unit.count} atlasBase=${unit.atlasBase} slots=${unit.animCount}`);
console.log(`wrote ${outPath}  (${width}x${height})`);
console.log(`clip markers: turn=red die=blue walk=green act1=yellow act2=magenta act3=cyan unused=grey`);
console.log(legend.join('\n'));
