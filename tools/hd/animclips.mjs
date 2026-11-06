#!/usr/bin/env node
/**
 * animclips.mjs — build the named animation clip table for UNIT.LWC unit types.
 *
 * Sources (all static, no guessing):
 *   Set\UNIT.EXP   -> per unit type: W,H,cols,rows  (frames = cols*rows, laid out row-major)
 *   Set\ANISEQ01.EXP -> per unit id: [animCount][baseFrame] then animCount x (slot, n, frame[n])
 *   Set\ANISEQ02.EXP -> per unit id: 7 dwords; file order maps to struct tail fields
 *                       (sscanf order at CB.EXE 0x445d20): [+0x560][+0x548][+0x54C][+0x550][+0x554][+0x558][+0x55C]
 *   CB.EXE (decompiled) -> slot = clipBase + direction (8 directions), see docs/17-art.md
 *
 * Outputs:
 *   _work/dec/anim_clips.json   machine-readable clip table
 *   stdout                      arithmetic check report
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'latin1');

// ---------------------------------------------------------------- UNIT.EXP
const expRaw = read('_work/dec/UNIT.EXP.txt');
const declared = Number(expRaw.match(/^\s*(\d+)/)[1]);
const reUnit = /(\d+)\s+(\S+)\s+(\S+)\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s+(\d+),\s*(\d+)/g;
const units = [];
let m;
while ((m = reUnit.exec(expRaw))) {
  units.push({
    id: +m[1], sprite: m[2], logical: m[3],
    W: +m[4], H: +m[5], a: +m[6], b: +m[7],
    cols: +m[8], rows: +m[9], count: +m[8] * +m[9],
    base: 0,
  });
}
let acc = 0;
for (const u of units) { u.base = acc; acc += u.count; }

// --------------------------------------------------------------- ANISEQ01
// Grammar (verified: consumes every numeric token, 0 leftover):
//   <N>  then N x ( id, animCount, baseFrame, animCount x ( slot, n, frame[n] ) )
function parseAniseq01(file) {
  const nums = read(file).match(/\d+/g).map(Number);
  let p = 0;
  const N = nums[p++];
  const out = [];
  for (let r = 0; r < N; r++) {
    const id = nums[p++], nAnim = nums[p++], base = nums[p++];
    const anims = [];
    for (let a = 0; a < nAnim; a++) {
      const slot = nums[p++], n = nums[p++];
      const frames = nums.slice(p, p + n); p += n;
      anims.push({ slot, frames });
    }
    out.push({ id, nAnim, base, anims });
  }
  return { records: out, leftover: nums.length - p, tokens: nums.length };
}

// --------------------------------------------------------------- ANISEQ02
// Grammar: <N> then N x ( id, 7 dwords ) with "%d,%d,%d,%d,%d,%d,%d"
function parseAniseq02(file) {
  const nums = read(file).match(/\d+/g).map(Number);
  let p = 0;
  const N = nums[p++];
  const out = [];
  for (let r = 0; r < N; r++) {
    const id = nums[p++];
    const v = nums.slice(p, p + 7); p += 7;
    // file order -> struct offsets (from the sscanf argument order in FUN_00445d20)
    out.push({
      id, raw: v,
      f560: v[0], // direction-count / "instant facing" sentinel (== 8 special-cased)
      f548: v[1], f54c: v[2], f550: v[3], f554: v[4], f558: v[5], f55c: v[6],
    });
  }
  return { records: out, leftover: nums.length - p };
}

const a1 = parseAniseq01('_work/dec/ANISEQ01.EXP.txt');
const a2 = parseAniseq02('_work/dec/ANISEQ02.EXP.txt');

// ------------------------------------------------------------------ checks
const problems = [];
if (a1.leftover !== 0) problems.push(`ANISEQ01 token leftover ${a1.leftover}`);
if (a2.leftover !== 0) problems.push(`ANISEQ02 token leftover ${a2.leftover}`);
if (units.length !== declared) problems.push(`UNIT.EXP declared ${declared}, parsed ${units.length}`);
if (acc !== 2708) problems.push(`UNIT.EXP cumulative frames ${acc} != 2708`);

for (const u of units) {
  const r1 = a1.records.find((x) => x.id === u.id);
  if (!r1) { problems.push(`unit ${u.id}: no ANISEQ01 record`); continue; }
  if (r1.base !== u.base) {
    // id 52 is the known duplicate of id 48 (FORMATS 2.3.7). It reuses id 48's block.
    problems.push(`unit ${u.id}: ANISEQ01 base ${r1.base} != UNIT.EXP base ${u.base}${u.id === 52 ? '  [known: id 52 re-uses id 48 sprite block]' : ''}`);
  }
  // Per-unit record is 0x564 bytes: animCount + 48 dword counts + base + 48 slots x 0x18 bytes.
  // Frame lists are stored one byte per frame -> at most 0x18 = 24 frames per slot.
  if (r1.nAnim > 48) problems.push(`unit ${u.id}: animCount ${r1.nAnim} > 48 (count-array capacity)`);
  for (const a of r1.anims) {
    if (a.frames.length > 24) problems.push(`unit ${u.id} slot ${a.slot}: ${a.frames.length} frames > 24 (0x18-byte slot capacity)`);
    for (const f of a.frames) {
      if (f < 0 || f >= u.count) problems.push(`unit ${u.id} slot ${a.slot}: frame ${f} outside block 0..${u.count - 1} (abs ${f + u.base})`);
    }
    if (a.frames.some((f) => f > 255)) problems.push(`unit ${u.id} slot ${a.slot}: frame > 255 (byte storage)`);
  }
  const slots = r1.anims.map((a) => a.slot);
  const dup = slots.filter((s, i) => slots.indexOf(s) !== i);
  if (dup.length) problems.push(`unit ${u.id}: duplicate slot ids ${dup.join(',')}`);
  const missing = [];
  for (let s = 0; s < r1.nAnim; s++) if (!slots.includes(s)) missing.push(s);
  if (missing.length) problems.push(`unit ${u.id}: animCount=${r1.nAnim} but slots missing: ${missing.join(',')}`);
}

// ------------------------------------------------------- clip table build
// Absolute UNIT.LWC frame indices that docs/17-art.md 2.3.5 (script _work/findlabel.mjs)
// classifies as "label cards" / blank filler left over from the original art montage.
const LABEL_FRAMES = new Set([
  60, 112, 152, 184, 189, 381, 425, 597, 637, 743, 905,
  1182, 1183, 1185, 1264, 1265, 1267, 1304, 1363, 1364,
  1543, 1544, 1545, 1546, 1548, 1673, 1674, 1675, 1677,
  1822, 1837, 1838, 1839, 1998, 1999, 2000, 2002,
  2197, 2198, 2199, 2201, 2366, 2433, 2434, 2501, 2502,
  2555, 2568, 2623, 2669, 2670, 2705, 2706,
]);

const CLIP_NAMES = {
  f548: 'turn',
  f54c: 'die',
  f550: 'walk',
  f554: 'act1',
  f558: 'act2',
  f55c: 'act3',
};
// ANISEQ02 maps its 7 file values onto struct offsets (CB.EXE 0x445d20):
//   v1 -> +0x560   v2 -> +0x548   v3 -> +0x54C   v4 -> +0x550
//   v5 -> +0x554   v6 -> +0x558   v7 -> +0x55C
// Engine usage (line numbers in docs/17-art.md):
//   +0x548 slot = base + dir : played while the facing is rotated (spawn/turn), AI fallback
//   +0x54C die (death): slot = base + dir when +0x560 == 8, otherwise the single slot `base`
//   +0x550 slot = base + dir : default animation of states 1/5/7/9 (move, work, command)
//   +0x554/+0x558/+0x55C : alternate action clips chosen by task sub-code or status flag
// A clip field whose value equals another clip's base shares that art block; the value 0
// therefore means "no art of its own - the engine falls back to the base-0 block".
const FIELD_ORDER = ['f548', 'f54c', 'f550', 'f554', 'f558', 'f55c'];

const clips = [];
for (const u of units) {
  const r1 = a1.records.find((x) => x.id === u.id);
  const r2 = a2.records.find((x) => x.id === u.id);
  const slotMap = new Map(r1.anims.map((a) => [a.slot, a.frames]));
  const entry = {
    id: u.id, sprite: u.sprite, logical: u.logical,
    W: u.W, H: u.H, cols: u.cols, rows: u.rows, count: u.count,
    atlasBase: u.base, atlasEnd: u.base + u.count - 1,
    // absolute frame numbering the engine actually uses (ANISEQ01 +0xC4 base frame);
    // identical to atlasBase for ids 0..51, but id 52 re-uses id 48's art block.
    frameBase: r1.base,
    animCount: r1.nAnim,
    dirFlag: r2 ? r2.f560 : null,
    bases: r2 ? Object.fromEntries(FIELD_ORDER.map((k) => [k, r2[k]])) : null,
    clips: {},
    unassignedSlots: [],
  };
  if (r2) {
    for (const key of FIELD_ORDER) {
      const name = CLIP_NAMES[key];
      const base = r2[key];
      // die is directional only for the types the engine indexes as base+dir (+0x560 == 8)
      const directional = !(name === 'die' && r2.f560 !== 8);
      const need = directional ? 8 : 1;
      const dirs = [];
      for (let d = 0; d < need; d++) {
        const s = base + d;
        if (!slotMap.has(s)) continue;
        dirs.push({
          dir: directional ? d : null, slot: s,
          framesRel: slotMap.get(s),
          // the engine adds the per-unit base frame from ANISEQ01 (+0xC4) to get the LWC index
          framesAbs: slotMap.get(s).map((f) => f + r1.base),
        });
      }
      entry.clips[name] = {
        field: key, base,
        kind: directional ? 'directional' : 'single',
        declared: need, present: dirs.length, complete: dirs.length === need,
        sharedBlockWith: r2.f548 === base ? 'turn' : FIELD_ORDER.filter((k) => k !== key && r2[k] === base).map((k) => CLIP_NAMES[k]),
        dirs,
      };
    }
  }
  const claimed = new Map();
  for (const key of FIELD_ORDER) {
    const cl = entry.clips[CLIP_NAMES[key]];
    if (!cl) continue;
    for (const d of cl.dirs) if (!claimed.has(d.slot)) claimed.set(d.slot, CLIP_NAMES[key]);
  }
  for (const s of [...slotMap.keys()].sort((x, y) => x - y)) {
    if (!claimed.has(s)) entry.unassignedSlots.push({ slot: s, framesRel: slotMap.get(s) });
  }
  entry.slotOwner = Object.fromEntries([...claimed].sort((a, b) => a[0] - b[0]));
  clips.push(entry);
}

// --------------------------------------------------------------- reporting
const outPath = path.join(ROOT, '_work/dec/anim_clips.json');
fs.writeFileSync(outPath, JSON.stringify({
  generatedBy: 'tools/hd/animclips.mjs',
  sources: {
    registry: 'Set/UNIT.EXP', sequence: 'Set/ANISEQ01.EXP', sequenceExt: 'Set/ANISEQ02.EXP',
    semantics: 'CB.EXE FUN_00445a70 (ANISEQ01 loader), FUN_00445d20 (ANISEQ02 loader), FUN_0045d440/FUN_0045dd90/FUN_0045f8b0/FUN_004522b0 (slot = base + dir)',
  },
  clipNames: CLIP_NAMES,
  units: clips,
}, null, 1));

// CSV: one row per (unit, clip, direction, playback step) - the flat form the prototype wants.
const csv = ['unitId,sprite,logical,clip,clipBase,clipKind,dir,slot,step,atlasFrame'];
for (const c of clips) {
  for (const name of ['turn', 'die', 'walk', 'act1', 'act2', 'act3']) {
    const cl = c.clips[name];
    if (!cl) continue;
    for (const d of cl.dirs) {
      d.framesAbs.forEach((f, i) => {
        csv.push([c.id, c.sprite, c.logical, name, cl.base, cl.kind, d.dir ?? '', d.slot, i, f].join(','));
      });
    }
  }
}
fs.writeFileSync(path.join(ROOT, '_work/dec/anim_clips.csv'), csv.join('\n') + '\n');
console.log(`wrote _work/dec/anim_clips.json and _work/dec/anim_clips.csv (${csv.length - 1} clip-step rows)`);

console.log(`parsed: UNIT.EXP ${units.length} types / ${acc} frames; ANISEQ01 ${a1.records.length} records; ANISEQ02 ${a2.records.length} records`);
console.log(`problems: ${problems.length}`);
for (const p of problems) console.log('  ! ' + p);

console.log('\n== per-type clip table (units 27..52; 0..26 are buildings) ==');
console.log('id spr      WxH    cols rows count aCount | dirFlag | turn die  walk act1 act2 act3  (base+slots)');
for (const c of clips) {
  if (c.id < 27) continue;
  const fmt = (n) => {
    const cl = c.clips[n];
    if (!cl) return '   -   ';
    const tag = cl.complete ? '' : `!${cl.present}/${cl.declared}`;
    const shared = cl.sharedBlockWith && cl.sharedBlockWith.length ? '*' : ' ';
    return `${String(cl.base).padStart(3)}${cl.kind === 'single' ? 's' : 'd'}${tag}${shared}`;
  };
  console.log(
    String(c.id).padStart(2), c.sprite.padEnd(7), `${c.W}x${c.H}`.padEnd(7),
    String(c.cols).padStart(3), String(c.rows).padStart(4), String(c.count).padStart(5), String(c.animCount).padStart(5),
    '|', String(c.dirFlag).padStart(4), '   |',
    ['turn', 'die', 'walk', 'act1', 'act2', 'act3'].map(fmt).join(' '),
    c.unassignedSlots.length ? `  UNASSIGNED slots:${c.unassignedSlots.map((s) => s.slot).join(',')}` : '',
  );
}
console.log('legend: <base>d = 8-directional block, <base>s = single slot, * = shares another clip\'s block, !n/m = incomplete');

// frame coverage: which frames of a unit block are referenced by any slot
console.log('\n== frame coverage (directional units only) ==');
for (const c of clips) {
  if (c.id < 27) continue;
  const used = new Set();
  for (const cl of Object.values(c.clips)) for (const d of cl.dirs) for (const f of d.framesRel) used.add(f);
  for (const s of c.unassignedSlots) for (const f of s.framesRel) used.add(f);
  const unused = [];
  for (let f = 0; f < c.count; f++) if (!used.has(f)) unused.push(f);
  const labels = LABEL_FRAMES;
  const unusedAbs = unused.map((f) => f + c.atlasBase);
  const unexplained = unusedAbs.filter((f) => !labels.has(f));
  console.log(
    `id ${String(c.id).padStart(2)} ${c.sprite.padEnd(7)} used ${String(used.size).padStart(3)}/${String(c.count).padStart(3)}`,
    `unusedAbs=[${unusedAbs.join(',')}]`,
    unexplained.length ? `  NOT-A-KNOWN-LABEL=[${unexplained.join(',')}]` : '  (all unused frames are known label cards)',
  );
}
if (problems.length === 0) console.log('\nALL STRUCTURAL CHECKS PASSED');
