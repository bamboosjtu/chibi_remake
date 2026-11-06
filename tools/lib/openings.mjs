#!/usr/bin/env node
/** Generate opening documentation from repository JSON only. No binary/dec inputs. */
import fs from 'node:fs';

const clean = s => String(s ?? '').replace(/\s+/g, '');
const readJson = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const outputPath = 'docs/reference/level-openings.md';
const previous = fs.existsSync(outputPath) ? fs.readFileSync(outputPath, 'utf8') : '';
const briefs = new Map();
for (const section of previous.split(/^### /m).slice(1)) {
  const map = section.match(/`(chibi[cl]\w*)`/i)?.[1];
  const brief = section.match(/^> 简报：(.*)$/m)?.[1];
  if (map && brief) briefs.set(map.toLowerCase(), brief);
}
const files = fs.readdirSync('godot/chibi_remake/data').filter(f => /^chibi[cl]\w*\.json$/i.test(f));
const documents = files.map(file => ({file, data:readJson('godot/chibi_remake/data/'+file)}));
const maps = documents.map(({file,data}) => ({file:file.replace(/\.json$/i,''), name:data.name, objects:data.objects}));
const missions = documents.map(({file,data}) => ({id:data.scenario.missionId, mapName:file.replace(/\.json$/i,''), aviName:data.scenario.avi, sides:data.scenario.sides})).sort((a,b)=>a.id-b.id);
const offj = readJson('godot/chibi_remake/data/db/officers.json');
const typeNames = new Map();
for (const {data} of documents) for (const [id, unit] of Object.entries(data.units)) typeNames.set(Number(id),clean(unit.name));
const typeName = id => typeNames.get(id) ?? `类型${id}`;
const byIdx = new Map();
for (const b of offj.blocks) for (const o of b.officers) byIdx.set(o.index, o);
const FACTION = { 1: '孙权军', 2: '刘备军', 3: '曹操军', 4: '荆州军' };
const mapByFile = new Map(maps.map(m => [m.file.toLowerCase(), m]));

function lineInfo(mapFile) {
  const m = /^CHIBI([CL])(\d+)([AB]?)$/i.exec(mapFile);
  if (!m) return { line: '?', label: mapFile };
  const [, c, n, suf] = m;
  return { line: c.toUpperCase(), label: `${c.toUpperCase()}${Number(n)}${suf.toUpperCase()}` };
}

function compText(objs) {
  const m = new Map();
  for (const o of objs) m.set(o.unit, (m.get(o.unit) ?? 0) + 1);
  return [...m.entries()].sort((a, b) => a[0] - b[0])
    .map(([id, n]) => `${typeName(id)}(${id})×${n}`).join('、');
}

function officerLine(off, rankText, comp) {
  const name = off ? clean(off.name) : '未知武将';
  const attr = off ? `武力 ${off.might}・智力 ${off.intellect}・${off.heroTypeName}` : '属性未知';
  return `  - **${name}**（${attr}；${rankText}）— ${comp}`;
}

function sideLines(s, map, playerOwner) {
  const objs = map.objects.filter(o => o.owner === s.owner);
  const troops = objs.filter(o => o.tail.length === 2);
  const blds   = objs.filter(o => o.tail.length !== 2 && o.tail.length !== 4);
  const res    = objs.filter(o => o.tail.length === 4);
  const byOfficer = new Map();
  for (const t of troops) {
    const id = t.tail[0];
    if (!byOfficer.has(id)) byOfficer.set(id, []);
    byOfficer.get(id).push(t);
  }
  const lines = [];
  const head = s.owner === playerOwner ? '★玩家' : '敌方';
  lines.push(`- ${head}：**${FACTION[s.owner] ?? `归属${s.owner}`}（o${s.owner}）**　资源：金 ${s.resources[0]}・粮 ${s.resources[1]}・木 ${s.resources[2]}・铁 ${s.resources[3]}　部队 ${troops.length} 支`);
  s.roster.forEach((idx, i) => {
    const off = byIdx.get(idx - 1);
    const rank = s.ranks[i];
    let level = rank > 0 ? rank - 1 : Number(off?.level ?? 0);
    if (idx <= 33 && level === 0) level = 5;
    const rankText = rank > 0 ? `档次 ${rank}（等级 ${level}）` : `档次 0（默认等级 ${level}）`;
    const ts = byOfficer.get(idx) ?? [];
    let comp = ts.length ? compText(ts) : '无开局部队';
    if (ts.length > 15) comp += '（超过 15，编入可能受限）';
    if (ts.length) byOfficer.delete(idx);
    lines.push(officerLine(off, rankText, comp));
  });
  for (const [idx, ts] of [...byOfficer.entries()].filter(([i]) => i !== 0).sort((a, b) => a[0] - b[0])) {
    lines.push(officerLine(byIdx.get(idx - 1), '地图额外（不在本关名单）', compText(ts)));
  }
  const un = byOfficer.get(0);
  if (un) lines.push(`  - 未编组部队 — ${compText(un)}`);
  if (blds.length) lines.push(`  - 建筑 — ${compText(blds)}`);
  if (res.length) lines.push(`  - 资源（本段）— ${compText(res)}`);
  return lines;
}

function emitLine(lineKey, title) {
  const sec = [`## ${title}`, ''];
  for (const m of missions) {
    const li = lineInfo(m.mapName);
    if (li.line !== lineKey) continue;
    const mp = mapByFile.get(m.mapName.toLowerCase());
    sec.push(`### ${li.label} · ${mp ? mp.name : m.mapName}`);
    sec.push('');
    const b = briefs.get(m.mapName.toLowerCase()) ?? '';
    sec.push(`\`${m.mapName}\` · 过场 \`${m.aviName}\``);
    if (b) sec.push('', `> 简报：${b}`);
    sec.push('');
    const playerOwner = m.sides[0].owner;
    for (const s of m.sides) sec.push(...sideLines(s, mp, playerOwner));
    const neutrals = mp ? mp.objects.filter(o => o.owner === 0) : [];
    if (neutrals.length) {
      const nt = compText(neutrals.filter(o => o.tail.length !== 2));
      const nu = compText(neutrals.filter(o => o.tail.length === 2));
      sec.push(`  - 中立/布景（全图）— ${[nt, nu].filter(Boolean).join('、')}`);
    }
    sec.push('');
  }
  return sec;
}

const out = [];
out.push('# 附录：各关开局配置');
out.push('');
out.push('> 覆盖 34 关：曹操线 C1–C17、刘备线 L1–L16（含 L7A/L7B）。');
out.push('> 数据来源：`godot/chibi_remake/data/chibi*.json`（参战方、资源、名单、档次、部队与建筑）与 `data/db/officers.json`（从 0 开始的武将索引）；关卡的统辖编号从 1 开始。生成入口 `node tools/lib/openings.mjs`。');
out.push('> 开局规则：地图中每支部队带统辖武将编号；加载时在该武将的首支部队位置生成武将本体（生命取类型基础值，士气 70），其余同编号部队编入其名下。武将等级 = 档次 − 1（档次 0 用默认等级；编号 1–33 且等级为 0 时置 5）。名单中未带兵的武将不自动出场。');
out.push('');
out.push('## 总览');
out.push('');
out.push('| 编号 | 关名 | 地图 | 过场 | 参战方（★＝单机玩家） |');
out.push('|---|---|---|---|---|');
const overviewOrder = [...missions].sort((a, b) => {
  const la = lineInfo(a.mapName), lb = lineInfo(b.mapName);
  const ka = (la.line === 'C' ? 0 : 1000) + parseInt(la.label.replace(/\D/g, ''), 10);
  const kb = (lb.line === 'C' ? 0 : 1000) + parseInt(lb.label.replace(/\D/g, ''), 10);
  return ka - kb || la.label.localeCompare(lb.label);
});
for (const m of overviewOrder) {
  const li = lineInfo(m.mapName);
  const mp = mapByFile.get(m.mapName.toLowerCase());
  const nick = m.sides.map((s, i) => (i === 0 ? '★' : '') + (FACTION[s.owner] ?? `o${s.owner}`)).join(' / ');
  out.push(`| ${li.label} | ${mp ? mp.name : ''} | ${m.mapName} | ${m.aviName} | ${nick} |`);
}
out.push('');
out.push(...emitLine('C', '曹操线（CHIBIC1–17）'));
out.push(...emitLine('L', '刘备线（CHIBIL1–16）'));
out.push('## 备注');
out.push('');
out.push('- 「地图额外」＝地图部队的统辖编号不在本关名单中（曹操/刘备两线共用部分地图，另一线名单可能包含该编号）。');
out.push('- 「未编组部队」＝统辖编号为 0 的部队（不触发武将登场）。');
out.push('- 名单中「无开局部队」的武将可经「调动部队」等后续机制登场。');
out.push('');

fs.mkdirSync('docs/reference', { recursive: true });
fs.writeFileSync(outputPath, out.join('\n'), 'utf8');
console.log(`written ${outputPath} (${out.length} lines)`);
