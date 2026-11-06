#!/usr/bin/env node
/**
 * medobjects — extract the placement lists from MEDS\*.MED (solver v2).
 *
 * Grammar (CB.EXE FUN_0042bd70 loader, FUN_00442970/FUN_0045ac40/FUN_00459e20
 * spawner; all verified with REA/Ghidra this session — see docs):
 *
 *   section: u16 count, then `count` entries:
 *     u8  used                     (0 = empty slot, entry is one byte)
 *     u16 A   -> obj+0x1a / grid row   (FUN_00459e20: *(short*)(obj+0x1a)=A)
 *     u16 B   -> obj+0x1c / grid col
 *     u16 C   -> obj+0x12 (state; 0 in all shipped maps)
 *     u32 D   -> owner=bits16-19, unitIndex=bits10-15, f4_9=bits4-9,
 *                f0_3=bits0-3, flags=bits20-21 (0 in all shipped maps)
 *     tail: class==0x02 -> 4 bytes | class in {03,07,08,0A,0B} -> 2 bytes | else 0
 *
 *   class = byte at UNIT-TYPE table + 8, which is a pure function of the unit
 *   index (`FUN_00424f50`: class==2; `FUN_00424f70`: class in the 5-set).
 *
 * The five sections are per-owner lists (verified: every object's owner == its
 * section index across all 34 maps).
 *
 * Solver: DFS over tail candidates {0,2,4} per first-seen unit with field-domain
 * constraints (A<rows, B<cols, C<256, D>>>22==0). A file is accepted only when
 * its walk ends exactly at EOF. Solutions merge across all 34 maps and must
 * agree per unit (cross-file consistency = independent verification).
 *
 * Output: dec/maps_scene.json (all solved maps), dec/tailmap.json.
 */
import fs from 'node:fs';
import path from 'node:path';

const CANDIDATES = [0, 2, 4];

export function header(buf) {
  const version = buf.readUInt32LE(0);
  const nameLen = buf.readUInt8(4);
  const nameBytes = buf.subarray(5, 5 + nameLen);
  let name;
  try { name = new TextDecoder('gbk').decode(nameBytes); } catch { name = nameBytes.toString('latin1'); }
  const rows = buf.readUInt32LE(5 + nameLen);
  const cols = buf.readUInt32LE(9 + nameLen);
  return { version, nameLen, name, rows, cols, dataStart: 33 + nameLen, layerBytes: 3 * rows * cols * 2 };
}

export function unpackD(d) {
  return {
    owner: (d >>> 16) & 0xf,
    unit: (d >>> 10) & 0x3f,
    f4_9: (d >>> 4) & 0x3f,
    f0_3: d & 0xf,
    f20: (d >>> 20) & 0x3,
  };
}

/** Field-domain check for one placed object (see grammar above). */
export function entryOk(A, B, C, D, h) {
  if (A >= h.rows || B >= h.cols) return false;
  if (C > 255) return false;
  if ((D >>> 22) !== 0) return false;
  return true;
}

/**
 * Walk the 5 sections from p0.
 * `tailOf(unit)` returns 0|2|4, or null when that unit is still undecided.
 */
export function walk(buf, p0, tailOf, h) {
  let p = p0;
  const objects = [];
  for (let sec = 0; sec < 5; sec++) {
    if (p + 2 > buf.length) return { ok: false, why: `sec ${sec} count past EOF`, p };
    const count = buf.readUInt16LE(p); p += 2;
    for (let i = 0; i < count; i++) {
      if (p + 1 > buf.length) return { ok: false, why: `sec ${sec} entry ${i} flag past EOF`, p };
      const used = buf.readUInt8(p); p += 1;
      if (!used) { objects.push({ sec, i, used: 0 }); continue; }
      if (p + 10 > buf.length) return { ok: false, why: `sec ${sec} entry ${i} payload past EOF`, p };
      const A = buf.readUInt16LE(p), B = buf.readUInt16LE(p + 2),
        C = buf.readUInt16LE(p + 4), D = buf.readUInt32LE(p + 6);
      p += 10;
      if (!entryOk(A, B, C, D, h)) return { ok: false, why: `sec ${sec} entry ${i} out of domain A=${A} B=${B} C=${C} D=${D}`, p };
      const u = unpackD(D);
      const t = tailOf(u.unit);
      if (t === null) return { ok: false, why: 'undecided', p, undecidedUnit: u.unit };
      if (p + t > buf.length) return { ok: false, why: `sec ${sec} entry ${i} tail past EOF`, p };
      const tail = [...buf.subarray(p, p + t)];
      p += t;
      objects.push({ sec, i, used, A, B, C, D, tail, ...u });
    }
  }
  return { ok: true, objects, p };
}

/**
 * DFS with backtracking over the tail candidates; updates `map` (unit -> tail)
 * in place. `map` is shared across files and grows as units are decided.
 * @returns {status:'ok',objects,steps} | {status:'fail'|'cap',steps}
 */
export function solveFile(buf, start, map, h, maxSteps = 5_000_000) {
  const tailOf = (u) => (map.has(u) ? map.get(u) : null);
  const decisions = []; // { unit, tried: 0..2 }
  let steps = 0;

  for (;;) {
    if (++steps > maxSteps) return { status: 'cap', steps };
    const r = walk(buf, start, tailOf, h);

    if (r.ok && r.p === buf.length) return { status: 'ok', objects: r.objects, steps };
    const hardFail = !r.ok && r.why !== 'undecided';

    if (r.ok || hardFail) {
      // backtrack: advance the most recent decision
      let advanced = false;
      while (decisions.length) {
        const d = decisions[decisions.length - 1];
        d.tried++;
        if (d.tried < CANDIDATES.length) { map.set(d.unit, CANDIDATES[d.tried]); advanced = true; break; }
        map.delete(d.unit); decisions.pop();
      }
      if (!advanced) return { status: r.ok ? 'over' : 'fail', steps };
      continue;
    }

    // undecided -> open a new choice point
    if (decisions.length >= 30) return { status: 'cap', steps };
    const u = r.undecidedUnit;
    map.set(u, CANDIDATES[0]);
    decisions.push({ unit: u, tried: 0 });
  }
}

function main() {
  const dir = process.argv[2] || 'iso/MEDS';
  const files = fs.readdirSync(dir).filter((n) => /\.med$/i.test(n)).sort();
  const map = new Map();
  const out = [];
  let allOk = true;

  for (const f of files) {
    const buf = fs.readFileSync(path.join(dir, f));
    const h = header(buf);
    const start = h.dataStart + h.layerBytes + 40;
    const snapshot = new Map(map);
    const r = solveFile(buf, start, map, h);
    let placed = 0;
    let status = r.status;
    if (r.status === 'ok') {
      const objs = r.objects.filter((o) => o.used);
      placed = objs.length;
    } else {
      allOk = false;
      map.clear(); snapshot.forEach((v, k) => map.set(k, v));
    }
    console.log(`${f.padEnd(15)} ${h.name.padEnd(10)} ${String(h.rows).padStart(4)}x${String(h.cols).padEnd(4)} ${r.status}${placed ? `: ${placed} objects` : ''} (steps ${r.steps})`);
    out.push({
      file: f, name: h.name, rows: h.rows, cols: h.cols, status,
      objects: (r.objects || []).filter((o) => o.used).map((x) => ({
        sec: x.sec, A: x.A, B: x.B, C: x.C, D: x.D,
        owner: x.owner, unit: x.unit, f4_9: x.f4_9, f0_3: x.f0_3, flags: x.f20, tail: x.tail,
      })),
    });
  }

  console.log(`\nunit -> tail length (${map.size} distinct units):`);
  const byTail = { 0: [], 2: [], 4: [] };
  for (const [u, t] of [...map.entries()].sort((a, b) => a[0] - b[0])) byTail[t].push(u);
  for (const t of [0, 2, 4]) console.log(`  tail ${t} (${byTail[t].length}): ${byTail[t].join(',')}`);
  console.log(allOk ? '\nALL MAPS SOLVED CONSISTENTLY' : '\nSOME MAPS FAILED — see above');

  fs.mkdirSync('dec', { recursive: true });
  fs.writeFileSync('dec/maps_scene.json', JSON.stringify(out));
  fs.writeFileSync('dec/tailmap.json', JSON.stringify({ tail0: byTail[0], tail2: byTail[2], tail4: byTail[4] }, null, 1));

  const all = out.flatMap((o) => o.objects);
  console.log(`\nplaced objects total: ${all.length}`);
  const owners = new Map(), units = new Map(), secs = new Map();
  for (const o of all) {
    owners.set(o.owner, (owners.get(o.owner) || 0) + 1);
    units.set(o.unit, (units.get(o.unit) || 0) + 1);
    secs.set(o.sec, (secs.get(o.sec) || 0) + 1);
  }
  console.log('  by owner  : ' + [...owners.entries()].sort((a, b) => a[0] - b[0]).map(([k, v]) => `${k}:${v}`).join('  '));
  console.log('  by unit   : ' + [...units.entries()].sort((a, b) => a[0] - b[0]).map(([k, v]) => `${k}:${v}`).join('  '));
  console.log('  by section: ' + [...secs.entries()].sort((a, b) => a[0] - b[0]).map(([k, v]) => `${k}:${v}`).join('  '));
  console.log('\nwrote dec/maps_scene.json + dec/tailmap.json');
}

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) main();
