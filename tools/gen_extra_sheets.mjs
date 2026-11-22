#!/usr/bin/env node
/**
 * gen_extra_sheets — 为"地图上没有实例、但玩家/AI 需要生产"的兵种补图集与元数据。
 *
 * 本轮用途：**运输船（47）**——原版 11/34 张水战图有 46/48/49，但没有任何 47 实例；
 * 47 只能由**船坞（20）生产**（§11.4 船坞菜单）。没有 47 就没有"上船/装载"可玩。
 *
 * 做法（与 tools/godot_export.mjs 的 EXTRA_SHEET_UNITS 段同一套解码/元数据口径）：
 *   · UNIT.EXP 取图集记录（Uni121z / 96×74 / 68 帧 / first 2436）；
 *   · UNIT.LWC 逐帧解码（decodeFrame，按 owner 加队伍配色偏移）；
 *   · DATA.EXP 取属性（名/HP/攻/防/视野/射程/造价/经验/士气）；
 *   · anim_clips.json 取动画剪辑；
 *   · 写 sprites/sheet_<id>_o<owner>.png（1×，无 HD 源时不做伪超分），
 *     并把 meta 注入每张图的 data/<map>.json（`sheet` 指向**该图玩家阵营**的图集）。
 *
 * 用法：node tools/gen_extra_sheets.mjs --units 47 [--dry]
 */
import fs from 'node:fs';
import { useRuntimeArt } from './lib/runtime_art_refs.mjs';
import path from 'node:path';
import { parseUnitExp } from './lib/exptable.mjs';
import { parseDataExp, UNIT_FIELDS } from './lib/dataexp.mjs';

const TEAM_OFFSETS = [199, 31, 9, 97, 141]; // owner → 调色板偏移（同 godot_export.mjs）
const SHEET_COLS = 8;
const argv = process.argv.slice(2);
const dry = argv.includes('--dry');
const force = argv.includes('--force');
const unitsArg = (argv[argv.indexOf('--units') + 1] ?? '').split(',').filter(Boolean).map(Number);
const ids = unitsArg.length ? unitsArg : [47];
const root = { bmp: '_work/iso/BMP', set: '_work/iso/SET', pal: '_work/iso/RES/BATTLE.PAL' };
const dataDir = path.join('godot', 'chibi_remake', 'data');
const spritesDir = path.join('godot', 'chibi_remake', 'sprites');

const reg = parseUnitExp(path.join(root.set, 'UNIT.EXP'));
const dexp = parseDataExp(path.join(root.set, 'DATA.EXP'));
const attrById = new Map();
for (const u of dexp.units) {
  const m = {};
  UNIT_FIELDS.forEach((f, i) => { m[f.name] = u.v[i]; });
  attrById.set(u.id, { name: u.name, ...m });
}
const animPath = '_work/dec/anim_clips.json';
const animDb = fs.existsSync(animPath) ? JSON.parse(fs.readFileSync(animPath, 'utf8')) : null;
const clipsFor = (unitId) => {
  if (!animDb) return null;
  const a = animDb.units[String(unitId)];
  if (!a || !a.clips) return null;
  const out = {};
  for (const [name, c] of Object.entries(a.clips)) {
    if (!c || !Array.isArray(c.dirs) || c.dirs.length === 0) continue;
    out[name] = c.dirs.map((d) => d.framesRel);
  }
  return Object.keys(out).length ? out : null;
};
// Native sheets are research data, not runtime output.

const maps = fs.readdirSync(dataDir).filter((f) => f.endsWith('.json') && f !== 'db');
let injectedMaps = 0;
const madeSheets = new Set();
for (const f of maps) {
  const p = path.join(dataDir, f);
  const data = JSON.parse(fs.readFileSync(p, 'utf8'));
  if (!data.units || !data.objects) continue;
  const owners = new Set();
  for (const ob of data.objects) owners.add(Number(ob.owner));
  const sides = (data.scenario && data.scenario.sides) || [];
  for (const sd of sides) owners.add(Number(sd.owner));
  const playerOwner = sides.length ? Number(sides[0].owner) : 2;
  let changed = false;
  for (const id of ids) {
    if (data.units[String(id)] && !force) continue;
    const rec = reg.units.find((x) => x.id === id);
    const attr = attrById.get(id);
    if (!rec || !attr) continue;
    data.units[String(id)] = {
      name: attr.name,
      spriteName: rec.spriteName,
      w: rec.width,
      h: rec.height,
      frames: { first: rec.firstFrame, count: rec.frameCount, cols: SHEET_COLS },
      clips: clipsFor(id) || {},
      f9: attr.f9 ?? 100,
      sheetK: 1,
      sheet: `sprites/sheet_${String(id).padStart(3, '0')}_o${playerOwner}.png`,
      hp: attr.hp,
      attack: attr.attack,
      attackB: attr.attackB,
      defence: attr.defenceA,
      defenceB: attr.defenceB,
      vision: attr.vision,
      range: attr.range,
      mitig: attr.defenceA,
      mitig2: attr.defenceB,
      alt: attr.attackB,
      costs: [attr.costGold, attr.costWood, attr.costFood],
      costStone: attr.costStone,
      expGain: attr.expGain,
      moraleGain: attr.moraleGain,
      note: '由 tools/gen_extra_sheets.mjs 注入：地图无实例，供船坞生产，使用高清图集',
    };
    changed = true;
  }
  if (changed) {
    if (!dry) fs.writeFileSync(p, JSON.stringify(useRuntimeArt(data)));
    injectedMaps++;
  }
}
console.log(dry ? `dry: would inject ${injectedMaps} maps, sheets ${[...madeSheets].length}` : `injected ${injectedMaps} maps, wrote ${madeSheets.size} sheets`);
