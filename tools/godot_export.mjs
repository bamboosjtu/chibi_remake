#!/usr/bin/env node
/**
 * godot_export — build the Godot 4 verifier project for a .MED map.
 *
 * Uses the verified CB.EXE rendering model:
 *   - terrain baked 1:1 from .MED + LIB.LWC + GROUND.EXP (tools/lib/terrain_bake.mjs)
 *   - objects placed at  x = 44*A + 22*(B&1) + 22 - w/2
 *                       y = 11*B + 22 - h        (FUN_0045a6f0, bottom-anchored)
 *   - unit sprites decoded per owner with team recolour offsets on the palette
 *     band 0x4B..0x55 (FUN_00455cb0)
 *
 * Default output: data/<map>.json with native positions, animation indices and
 * HD catalog references. No native or supersampled images enter the runtime tree.
 * --legacy-art exports native terrain/sheets to a separate research directory.
 *
 * Usage (run from the repo root):
 *   node tools/godot_export.mjs <outDir> [--map CHIBIC1] [--meds ..] [--bmp ..]
 *        [--set ..] [--pal ..] [--tailmap ..] [--no-team]
 */
import fs from 'node:fs';
import { useRuntimeArt } from './lib/runtime_art_refs.mjs';
import { completeBuildings } from './lib/building_registry.mjs';
import path from 'node:path';
import {loadMapObjects} from './lib/map_export_input.mjs';
import {buildNavigation} from './lib/map_export_navigation.mjs';
import {writeMapExport} from './lib/map_export_output.mjs';
import { parseUnitExp } from './lib/exptable.mjs';
import { loadBank, decodeFrame } from './lib/unitdec.mjs';
import { writePng } from './lib/unit2png.mjs';
import { readPal } from './lib/lwc2png.mjs';
import { bakeMap, TILE_W } from './lib/terrain_bake.mjs';
import { waterCells } from './lib/water_grid.mjs';
import { parseDataExp, UNIT_FIELDS } from './lib/dataexp.mjs';
import { parseBattleExp } from './lib/scenario.mjs';

/** 读 PNG 头部拿宽度（用于按实际尺寸推导每表倍率，支持混合 ×4 / ×2）。 */
function pngWidth(file) {
  const fd = fs.openSync(file, 'r');
  const b = Buffer.alloc(24);
  fs.readSync(fd, b, 0, 24, 0);
  fs.closeSync(fd);
  return b.readUInt32BE(16);
}

// Team recolour offsets added to palette indices 0x4B..0x55 (FUN_00455cb0).
// VERIFIED: +199 = magenta ramp (BATTLE.PAL 18..28) on a real battle screenshot.
// The other four target the remaining clean 11-colour army ramps in BATTLE.PAL:
// +9 red(@84), +31 blue(@106), +97 teal(@172), +141 green(@216).
// owner -> offset assignment is PROVISIONAL (needs runtime cross-check).
const TEAM_OFFSETS = [199, 31, 9, 97, 141];   // 2026-10-16 用户订正：o1=蓝/o2=红(刘备)/o3=青绿(曹操)/o4=绿灰

const argv = process.argv.slice(2);
if (!argv.length || argv[0].startsWith('--')) {
  console.error('usage: node tools/godot_export.mjs <outDir> [--map CHIBIC1] [--meds _work/iso/MEDS] [--bmp _work/iso/BMP] [--set _work/iso/SET] [--pal _work/iso/RES/BATTLE.PAL] [--tailmap _work/dec/tailmap.json] [--no-team]');
  process.exit(2);
}
const o = {
  outDir: argv[0],
  map: 'CHIBIC1',
  meds: '_work/iso/MEDS',
  bmp: '_work/iso/BMP',
  set: '_work/iso/SET',
  pal: '_work/iso/RES/BATTLE.PAL',
  tailmap: '_work/dec/tailmap.json',
  team: true,
};
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--map') o.map = argv[++i];
  else if (a === '--meds') o.meds = argv[++i];
  else if (a === '--bmp') o.bmp = argv[++i];
  else if (a === '--set') o.set = argv[++i];
  else if (a === '--pal') o.pal = argv[++i];
  else if (a === '--tailmap') o.tailmap = argv[++i];
  else if (a === '--legacy-art') o.legacyArt = true;
  else if (a === '--hd') o.hd = true;
  else if (a === '--hd-sprites') o.hdSprites = true;
  else if (a === '--no-team') o.team = false;
  else throw new Error(`unknown option ${a}`);
}

// Native image export is a research tool, never a runtime-project dependency.
const runtimeRoot = path.resolve('godot/chibi_remake');
if (o.legacyArt && (path.resolve(o.outDir) === runtimeRoot || path.resolve(o.outDir).startsWith(runtimeRoot + path.sep)))
  throw new Error('--legacy-art requires a separate research output directory');

// ---------- 1. solve the map's object table ----------
const {buf, h, objects} = loadMapObjects(o);

// ---------- 1b. walkable grid (placement rule FUN_0045a9b0 + layer decor) ----------
const { parseMed } = await import('./lib/medmap.mjs');
const mm = parseMed(buf);
// 通行性（**移动**）：layer 0 class ∈ {f,8,9}，且 layer 1/2 无结构装饰。
//   证据：0x45a9b0 是放置规则（返回值 3/8/2/6/10/0x14 = 能否在此建造）；
//   移动判定在路径循环里查 layer 0：uVar7 = t0 >> 0xc，必须 ∈ {0xf, 8, 9}。
//   2026-10-16 订正：层 1/2 非空 = 砖墙/崖壁/岩壁/城垛/木栅栏（LIB 帧 6/7/8/9/12，
//   全部经渲染分类核对）——**这些结构物必须挡移动**。此前"只查 layer 0"的版本
//   让单位能穿过栅栏与崖壁（用户实测），已改为两者同时判定。
const {terrainWalk, walk, decor, gateOpen} = buildNavigation(mm, objects);
if (gateOpen) console.log(`gate passages: ${gateOpen} cells opened`);
console.log(`decor(trees/grain): ${decor.length} cells`);

// ---------- 2. bake real terrain ----------
console.log(o.legacyArt ? 'baking research terrain ...' : 'exporting level metadata with HD references ...');
const baked = o.legacyArt ? bakeMap({ map: o.map, meds: o.meds, bmp: o.bmp, set: o.set, pal: o.pal }) : { W: TILE_W * mm.rows + 88, H: 11 * mm.cols + 160 };
fs.mkdirSync(o.outDir, { recursive: true });
const { writeRgbPng } = await import('./lib/lwc_sheet.mjs');
const terrainFile = `terrain_${o.map.toLowerCase()}.png`;
if (o.legacyArt) writeRgbPng(path.join(o.outDir, terrainFile), baked.W, baked.H, baked.rgb);
const hdQuads = [];
if (o.legacyArt && o.hd) {
  for (let q = 0; q < 4; q++) {
    const src = path.join('_work/hd/terrain4', `${o.map.toLowerCase()}_q${q}.png`);
    if (fs.existsSync(src)) {
      const dst = `terrain_hd/${o.map.toLowerCase()}_q${q}.png`;
      fs.mkdirSync(path.join(o.outDir, 'terrain_hd'), { recursive: true });
      fs.copyFileSync(src, path.join(o.outDir, dst));
      hdQuads.push(dst);
    }
  }
}

// ---------- 3. unit registry + per-owner sprite SHEETS (all frames, 16-col grid) ----------
const reg = parseUnitExp(path.join(o.set, 'UNIT.EXP'));
// DATA.EXP = the master table: 27 buildings (ids 0..26) + 26 unit types (ids 27..52).
// It supplies the Chinese names AND the real attributes (see docs/15-data-spec.md).
const dexp = parseDataExp(path.join(o.set, 'DATA.EXP'));
const attrById = new Map();
for (const u of dexp.units) {
  const m = {};
  UNIT_FIELDS.forEach((f, i) => { m[f.name] = u.v[i]; });
  attrById.set(u.id, { name: u.name, ...m });
}
const bldById = new Map(dexp.buildings.map((b) => [b.id, { name: b.name, hp: b.v[0], v: b.v }]));
console.log(`DATA.EXP: ${bldById.size} buildings, ${attrById.size} unit types, ${dexp.officerBlocks.reduce((s, b) => s + b.length, 0)} officers`);
// 兵种 id -> HP（武将 HP 的来源，见下面的 TIER_HERO 说明）
const hpOf = new Map();
for (const [id, m] of attrById) hpOf.set(id, m.hp);

// ---------- 3a. officer roster -> data/db/officers.json ----------
// ARCH-005：数据库不能放在 data/ 下，否则会被 game.gd::list_levels 当成关卡。
// DATA.EXP 第 5 段：4 个阵营块，顺序即游戏内的全局索引
// （块 0=孙权 33 人、1=刘备 14 人、2=曹操 51 人、3=荆州 19 人；共 117）
fs.mkdirSync(path.join(o.outDir, 'data', 'db'), { recursive: true });
{
  let gi = 0;
  const blocks = dexp.officerBlocks.map((blk, bi) => ({
    faction: bi + 1,
    firstIndex: blk.length ? gi : -1,
    officers: blk.map((x) => {
      // 武将 HP 与「将」类兵种由 **tier** 决定（CB.EXE 武将装载器 L49071-49120）：
      //   local_110=0x23(35) local_10c=0x1f(31) local_108=0x21(33) local_104=0x1d(29)
      //   HP[o] = *(int*)(&DAT_004af584 + tier_map[tier] * 0x38);   ← 文本第 5 个整数被**覆盖**
      // 即：tier 1→骑将35 / 2→步将31 / 3→弓将33 / 4→文将29，HP 取该兵种的 HP。
      // **必须写在这里**：本文件每次导出都会重写 officers.json，
      // 事后用 tools/lib/officer_hp.mjs 补字段会被下一次导出抹掉（已踩过）。
      const TIER_HERO = { 1: 35, 2: 31, 3: 33, 4: 29 };
      const HERO_NAME = { 35: "骑将", 31: "步将", 33: "弓将", 29: "文将" };
      const heroType = TIER_HERO[x.tier] ?? null;
      const heroHp = heroType != null ? (hpOf.get(heroType) ?? null) : null;
      return {
        index: gi++,
        name: x.name,
        might: x.might,        // 武力 (+0x15)
        intellect: x.intellect,// 智力 (+0x16)
        tier: x.tier,          // 档次 (+0x17)
        level: x.d - 1,        // 等级 (+0x18)，装载时 -= 1
        heroType,              // 该武将组建时变成的「将」类兵种 id
        heroTypeName: heroType != null ? HERO_NAME[heroType] : null,
        hp: heroHp,            // 组建时单位的 HP 取自这里
      };
    }),
  }));
  fs.writeFileSync(path.join(o.outDir, 'data', 'db', 'officers.json'),
    JSON.stringify({ kind: 'officerDatabase', schemaVersion: 1, blocks }, null, 0));
  console.log(`officers: ${gi} written to data/db/officers.json`);
}
// 本关的战役定义（BATTLE.EXP，按地图名匹配）—— 玩家归属/初始资源/参战方/武将名单
const campaign = parseBattleExp(path.join(o.set, 'BATTLE.EXP'));
const scen = campaign.missions.find((m) => m.mapName.toLowerCase() === `${o.map.toLowerCase()}.med`) || null;
if (scen) {
  console.log(`scenario: mission ${scen.id} ${scen.mapName} sides=${scen.sides.map((x) => 'o' + x.owner).join('/')} player=o${scen.sides[0].owner}`);
} else {
  console.log('scenario: 未在 BATTLE.EXP 里找到本图，使用原型默认规则');
}
// ARCH-009：原版的单位动画是**显式序列表**（ANISEQ01/02.EXP），不是"帧数 ÷ 8"。
// 表由 tools/hd/animclips.mjs 建好（文件解析 + 载入器 + GAME0.SAV 运行时快照三方一致）。
// framesRel 就是该兵种图集内的**局部帧号**，正好可以直接喂给 region_rect。
const ANIM_PATH = '_work/dec/anim_clips.json';
const animDb = fs.existsSync(ANIM_PATH) ? JSON.parse(fs.readFileSync(ANIM_PATH, 'utf8')) : null;
if (!animDb) console.log('WARNING: 缺少 ' + ANIM_PATH + ' —— 动画将回退到旧的 count/8 猜测');
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

const bank = loadBank(`${o.bmp}/UNIT.LWC`, `${o.bmp}/UNIT.IDX`);
const palette = readPal(o.pal);

const spritesDir = path.join(o.outDir, 'sprites');
if (o.legacyArt) fs.mkdirSync(spritesDir, { recursive: true });

const SHEET_COLS = 8;
const unitMeta = {};
const missing = [];
const sheetKeys = new Set();
let hdSheets = 0;
for (const ob of objects) {
  const u = ob.unit, owner = ob.owner;
  const rec = reg.units.find((x) => x.id === u);
  if (!rec) { missing.push(`${u}`); continue; }
  if (rec.firstFrame + rec.frameCount > bank.idx.length) { missing.push(`${u}(atlas)`); continue; }
  const off = o.team ? (TEAM_OFFSETS[owner] ?? 0) : 0;
  const key = `${u}_${owner}`;
  const file = `sheet_${String(u).padStart(3, '0')}_o${owner}.png`;
  if (o.legacyArt && !sheetKeys.has(key)) {
    const n = rec.frameCount;
    const rows = Math.ceil(n / SHEET_COLS);
    const sw = SHEET_COLS * rec.width, sh = rows * rec.height;
    const sheetBuf = Buffer.alloc(sw * sh);
    for (let i = 0; i < n; i++) {
      const fr = decodeFrame(bank, rec.firstFrame + i, { teamOffset: off });
      const cx = (i % SHEET_COLS) * rec.width, cy = Math.floor(i / SHEET_COLS) * rec.height;
      for (let y = 0; y < fr.h; y++) {
        sheetBuf.set(fr.px.subarray(y * fr.w, y * fr.w + fr.w), (cy + y) * sw + cx);
      }
    }
    writePng(path.join(spritesDir, file), sw, sh, sheetBuf, palette);
    sheetKeys.add(key);
  }
  let sheetRef = `sprites/${file}`;
  let hdK = 1;
  if (o.legacyArt && o.hdSprites) {
    const hdFile = path.join('_work/hd/sprites4_rgba', file);
    if (fs.existsSync(hdFile)) {
      fs.mkdirSync(path.join(o.outDir, 'sprites_hd'), { recursive: true });
      fs.copyFileSync(hdFile, path.join(o.outDir, 'sprites_hd', file));
      sheetRef = `sprites_hd/${file}`;
      // 每表倍率按**实际尺寸比**推导（支持混合 ×4 / ×2；见 _work/hd 的逐表降档）。
      hdK = Math.max(1, Math.round(pngWidth(hdFile) / (SHEET_COLS * rec.width)));
      hdSheets++;
    }
  }
  const attr = attrById.get(u);
  const bld = bldById.get(u);
  unitMeta[String(u)] = {
    // 中文原名：建筑取建筑表，兵种取兵种表（DATA.EXP）
    name: (attr && attr.name) || (bld && bld.name) || rec.name,
    spriteName: rec.spriteName,
    w: rec.width, h: rec.height,
    frames: { first: rec.firstFrame, count: rec.frameCount, cols: SHEET_COLS },
    // ARCH-009：真实动画剪辑表（turn/die/walk/act1/act2/act3 × 8 朝向，局部帧号）
    // 注意：**绝不能写 null** —— GDScript 的 dict.get(key, default) 在
    // 「key 存在但值为 null」时返回 null，default 不生效，于是 float(null) 报错。
    clips: clipsFor(u) || {},
    f9: attr ? attr.f9 : 100,    // 帧门限 = 1000 / f9 个原始 tick（见 docs/17-art.md §5）
    // ARCH-004：**每张图集自己的**倍率。以前是全图一个 spriteK，
    // 只要有一张 HD 存在，其余 1× 图集也被按 4× 区域切片 → 裁错/消失/尺寸错。
    sheetK: hdK,
    ...(attr ? {
      hp: attr.hp, attack: attr.attack, attackB: attr.attackB,
      defence: attr.defenceA, defenceB: attr.defenceB,
      vision: attr.vision, range: attr.range,
      // 战斗用字段（2026-10-16 REA 定名，见 docs/15-data-spec.md §10）：
      //   普通守方防御 = 防A(+0x1A) + 职业加成；将守方 = 武力 × 防A / 100 (FUN_00425b50)
      //   第二口径（射击）+0x19/+0x1B；职业加成表（0x4b01b0）尚未导出 → attack_bonus 仍为 0
      mitig: attr.defenceA, mitig2: attr.defenceB, alt: attr.attackB,
      costs: [attr.costGold, attr.costWood, attr.costFood], costStone: attr.costStone,
      expGain: attr.expGain, moraleGain: attr.moraleGain,
    } : {}),
    ...(bld && !attr ? { hp: bld.hp, building: true } : {}),
  };
  ob._sheet = sheetRef;
  ob._w = rec.width;
  ob._h = rec.height;
}
// ---------- 3b. AI 训练用图集（本轮新增）----------
// 原版每个兵种都有图；我们的导出器以前只为"地图上出现过的"兵种出图集，
// 于是 AI 按等级表训练 42/43/44 这些高档兵种时 _spawn_unit 找不到图 → 训练失败
// （表现为 "WARNING: spawn failed: unknown unit 42"）。
// 这里补齐：AI 任何等级可能训练的兵种，都为其**参战归属**出图集。
// ARMY_BY_TIER 的并集 + **四种「将」类兵种**。
// 将类是「组建」造出来的单位：武将的 tier 决定他是骑将/步将/弓将/文将
// （CB.EXE 武将装载器的 tier_map = 35/31/33/29，见 tools/lib/officer_hp.mjs 头部）。
// 没有这四张图集，组建就没法把士兵变成将单位。
const EXTRA_SHEET_UNITS = [34, 37, 38, 39, 40, 41, 42, 43, 44, 35, 31, 33, 29, 47];
{
  const owners = new Set();
  if (scen) for (const sd of scen.sides) owners.add(sd.owner);
  for (const ob of objects) owners.add(ob.owner);
  let extra = 0;
  for (const u of EXTRA_SHEET_UNITS) {
    const rec = reg.units.find((x) => x.id === u);
    if (!rec) continue;
    if (rec.firstFrame + rec.frameCount > bank.idx.length) continue;
    for (const owner of owners) {
      const key = `${u}_${owner}`;
      if (sheetKeys.has(key)) continue;                 // 地图里已有 → 跳过
      const off = o.team ? (TEAM_OFFSETS[owner] ?? 0) : 0;
      const file = `sheet_${String(u).padStart(3, '0')}_o${owner}.png`;
      if (o.legacyArt) {
      const n = rec.frameCount;
      const rows = Math.ceil(n / SHEET_COLS);
      const sw = SHEET_COLS * rec.width, sh = rows * rec.height;
      const sheetBuf = Buffer.alloc(sw * sh);
      for (let i = 0; i < n; i++) {
        const fr = decodeFrame(bank, rec.firstFrame + i, { teamOffset: off });
        const cx = (i % SHEET_COLS) * rec.width, cy = Math.floor(i / SHEET_COLS) * rec.height;
        for (let y = 0; y < fr.h; y++) {
          sheetBuf.set(fr.px.subarray(y * fr.w, y * fr.w + fr.w), (cy + y) * sw + cx);
        }
      }
      writePng(path.join(spritesDir, file), sw, sh, sheetBuf, palette);
      sheetKeys.add(key);
      extra++;
      }
      // HD 版本（若已超分；倍率按实际尺寸比推导）
      let hdK2 = 1;
      if (o.legacyArt && o.hdSprites) {
        const hdFile = path.join('_work/hd/sprites4_rgba', file);
        if (fs.existsSync(hdFile)) {
          fs.mkdirSync(path.join(o.outDir, 'sprites_hd'), { recursive: true });
          fs.copyFileSync(hdFile, path.join(o.outDir, 'sprites_hd', file));
          hdK2 = Math.max(1, Math.round(pngWidth(hdFile) / sw));
          hdSheets++;
        }
      }
      // 元数据：AI 训练时需要（名字/HP/造价/图集倍率/剪辑）
      if (!unitMeta[String(u)]) {
        const attr = attrById.get(u);
        const hdOk = o.hdSprites && fs.existsSync(path.join(o.outDir, 'sprites_hd', file));
        unitMeta[String(u)] = {
          name: (attr && attr.name) || rec.name,
          spriteName: rec.spriteName,
          w: rec.width, h: rec.height,
          frames: { first: rec.firstFrame, count: rec.frameCount, cols: SHEET_COLS },
          clips: clipsFor(u) || {},
          f9: attr ? attr.f9 : 100,
          sheetK: hdK2,
          sheet: (hdOk ? 'sprites_hd/' : 'sprites/') + file,
          ...(attr ? {
            hp: attr.hp, attack: attr.attack, attackB: attr.attackB,
            defence: attr.defenceA, defenceB: attr.defenceB,
            vision: attr.vision, range: attr.range,
            mitig: attr.defenceA, mitig2: attr.defenceB, alt: attr.attackB,
            costs: [attr.costGold, attr.costWood, attr.costFood], costStone: attr.costStone,
            expGain: attr.expGain, moraleGain: attr.moraleGain,
          } : {}),
        };
      }
    }
  }
  console.log(`extra AI-trainable sheets: ${extra}`);
}

if (missing.length) console.log(`WARNING: units without sprite: ${[...new Set(missing)].join(', ')}`);

completeBuildings(unitMeta, reg, dexp, JSON.parse(fs.readFileSync('godot/chibi_remake/art/full/manifest.json')));
// ---------- 4. pixel positions + data json ----------
const data = {
  map: o.map,
  // ARCH-007：#5 从 BATTLE.EXP 得到的每关规则（玩家归属/初始资源/参战方/名单）。
  // null = 未在战役表里找到，调用方必须回退到原型规则并显式标注。
  scenario: scen ? {
    missionId: scen.id,
    avi: scen.aviName,
    sides: scen.sides.map((x) => ({
      owner: x.owner,
      init: x.init,
      resources: x.resources,
      roster: x.roster,
      ranks: x.ranks,
    })),
  } : null,
  name: (() => { try { return new TextDecoder('gbk').decode(buf.subarray(5, 5 + buf.readUInt8(4))); } catch { return '?'; } })(),
  terrain: terrainFile,
  terrainW: baked.W,
  terrainH: baked.H,
  tileW: TILE_W,
  rows: mm.rows,
  cols: mm.cols,
  walkable: walk,
  terrainWalkable: terrainWalk,
  // 水军/运输船的通航层（水战批次）：MED ground set ∈ {3,4} 且 layer1/2 无结构。
  // 与 tools/lib/water_grid.mjs 同一实现；陆军仍用 terrainWalkable（见该文件头注的理由）。
  waterWalkable: Array.from(waterCells(mm)),
  decor,
  navigation: { schemaVersion: 1, topology: "staggered-diamond-four-edges", occupancy: "dynamic-footprints" },
  ...(hdQuads.length === 4 ? { terrainHD: hdQuads, terrainScale: 4 } : {}),
  ...(hdSheets > 0 ? { spriteK: 4 } : {}),
  note: 'terrain baked 1:1 from CB.EXE render model; object pos = 44A+22(B&1)+22-w/2 , 11B+22-h; walkable = FUN_0045a9b0 rule + layer1/2 decor + static buildings',
  objects: objects.map((x) => ({
    sec: x.sec, owner: x.owner, unit: x.unit, A: x.A, B: x.B, C: x.C, tail: x.tail,
    px: TILE_W * x.A + (TILE_W >> 1) * (x.B & 1) + 22 - (x._w >> 1),
    py: 11 * x.B + 22 - x._h,
    w: x._w, h: x._h, sheet: x._sheet,
  })),
  units: unitMeta,
};
if (!o.legacyArt) useRuntimeArt(data);
writeMapExport(o, data, {baked, objects, unitMeta, sheetKeys});
