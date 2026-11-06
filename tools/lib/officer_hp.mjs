// 武将 HP 的来源（CB.EXE 武将装载器，decompiled L49071-49120）：
//
//   local_110 = 0x23 (35)   local_10c = 0x1f (31)
//   local_108 = 0x21 (33)   local_104 = 0x1d (29)     ← 按 tier 1..4 索引
//   ...
//   _sscanf(..., "%s %d %d %d %d %d", name, &武力, &智力, &tier, &level, &HP)
//   (&level)[o] -= 1;                                  ← level 装载时 -1
//   HP[o] = *(int*)(&DAT_004af584 + tier_map[tier] * 0x38);   ← ★ HP 被**覆盖**
//
// 关键：文本里第 5 个整数确实读进了 HP 字段，但**紧接着就被覆盖** ——
// 真正的武将 HP = **该 tier 对应的"将"类兵种的 HP**。
//
//   35 = 骑将 / 31 = 步将 / 33 = 弓将 / 29 = 文将   （四个都是 HP 500）
//
// 所以武将的 tier 同时决定了他是什么类型的"将"。
import fs from 'node:fs';

const TIER_HERO_TYPE = { 1: 35, 2: 31, 3: 33, 4: 29 };
const UNIT_TYPE_NAME = { 35: '骑将', 31: '步将', 33: '弓将', 29: '文将' };

const units = JSON.parse(fs.readFileSync('_work/dec/data_exp.json', 'utf8')).units;
const hpOf = {};
for (const u of units) hpOf[u.id] = u.hp;

const p = 'godot/chibi_remake/data/db/officers.json';
const db = JSON.parse(fs.readFileSync(p, 'utf8'));
let n = 0;
for (const blk of db.blocks) {
  for (const o of blk.officers) {
    const t = int(o.tier);
    const heroType = TIER_HERO_TYPE[t];
    o.heroType = heroType ?? null;                  // 该武将对应的"将"类兵种
    o.heroTypeName = UNIT_TYPE_NAME[heroType] ?? null;
    o.hp = heroType ? hpOf[heroType] : null;        // ★ 原版规则：HP = 将类兵种的 HP
    n++;
  }
}
db.tierHeroType = TIER_HERO_TYPE;
db.note = 'hp/heroType 由 CB.EXE 武将装载器的 tier→将类兵种 映射导出（见 tools/lib/officer_hp.mjs 头部）';
fs.writeFileSync(p, JSON.stringify(db, null, 1));

function int(v) { const x = parseInt(v, 10); return Number.isFinite(x) ? x : -1; }

const dist = {};
for (const blk of db.blocks) for (const o of blk.officers) {
  const k = o.heroTypeName ?? '?';
  dist[k] = (dist[k] || 0) + 1;
}
console.log(`officers: ${n} 补上 hp / heroType -> ${p}`);
console.log('  将类分布:', JSON.stringify(dist));
console.log('  样例:', JSON.stringify(db.blocks[2].officers.find((o) => o.name.includes('曹'))));
