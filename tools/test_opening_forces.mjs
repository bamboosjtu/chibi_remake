// Compare the user-provided Markdown specification with repository JSON only.
// This never invokes the original-data exporter or reads game binaries.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const count = text => Object.fromEntries([...text.matchAll(/\((\d+)\)×(\d+)/g)].map(m => [m[1], Number(m[2])]));
const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => Number(a) - Number(b)));
const sum = counts => Object.values(counts).reduce((a, b) => a + b, 0);
const actualCounts = objects => {
  const result = {};
  for (const object of objects) result[object.unit] = (result[object.unit] ?? 0) + 1;
  return sorted(result);
};
const chapters = [];
const names = new Map();
for (const section of read('docs/reference/level-openings.md').split(/^### /m).slice(1)) {
  const id = section.match(/`(chibi[cl]\w*)`/i)[1].toLowerCase();
  const data = JSON.parse(read(`godot/chibi_remake/data/${id}.json`));
  const chapter = { id, sides: [], avi: section.match(/过场 `(.*?)`/)[1] };
  const pattern = /^- (★玩家|敌方)：\*\*(.+?)（o(\d+)）\*\*\s+资源：金 (\d+)・粮 (\d+)・木 (\d+)・铁 (\d+)\s+部队 (\d+) 支\n(.*?)(?=^- (?:★玩家|敌方)：|(?![\s\S]))/gms;
  for (const match of section.matchAll(pattern)) {
    const [, role, faction, ownerText, gold, food, wood, stone, total, body] = match;
    const owner = Number(ownerText);
    const source = data.scenario.sides[chapter.sides.length];
    assert.equal(source.owner, owner, `${id}: side owner`);
    const resources = { gold: Number(gold), food: Number(food), wood: Number(wood), stone: Number(stone) };
    assert.deepEqual(source.resources, [resources.gold, resources.food, resources.wood, resources.stone], `${id}: resources`);
    const officers = [];
    let rosterIndex = 0;
    for (const line of body.split('\n')) {
      if (!line.startsWith('  - **')) continue;
      const officer = line.match(/^  - \*\*(.*?)\*\*（武力 (\d+)・智力 (\d+)・.*?；(.*?)）— (.*)$/);
      assert.ok(officer, `${id}: officer row ${line}`);
      const [, name, might, intellect, rankText, troopsText] = officer;
      const rank = rankText.match(/档次 (\d+)/);
      const record = { name, might: Number(might), intellect: Number(intellect), rank: rank ? Number(rank[1]) : null, troops: count(troopsText) };
      if (rank) {
        record.id = source.roster[rosterIndex];
        assert.equal(source.ranks[rosterIndex++], record.rank, `${id}: rank of ${name}`);
        if (names.has(name)) assert.equal(names.get(name), record.id, `${id}: stable officer identity`);
        names.set(name, record.id);
      }
      officers.push(record);
    }
    assert.equal(rosterIndex, source.roster.length, `${id}: complete roster`);
    const buildings = count(body.match(/^  - 建筑 — (.*)$/m)?.[1] ?? '');
    const ungrouped = count(body.match(/^  - 未编组部队.*?— (.*)$/m)?.[1] ?? '');
    chapter.sides.push({ owner, faction, player: role === '★玩家', resources, total: Number(total), officers, buildings, ungrouped });
  }
  assert.equal(chapter.avi, data.scenario.avi);
  assert.equal(chapter.sides.length, data.scenario.sides.length, `${id}: all sides`);
  chapters.push(chapter);
}
assert.equal(chapters.length, 34);
let fullTeams = 0;
for (const chapter of chapters) {
  const data = JSON.parse(read(`godot/chibi_remake/data/${chapter.id}.json`));
  for (const side of chapter.sides) {
    const objects = data.objects.filter(o => o.owner === side.owner);
    assert.deepEqual(actualCounts(objects.filter(o => o.unit < 27)), sorted(side.buildings), `${chapter.id}: buildings owner${side.owner}`);
    let total = sum(side.ungrouped);
    for (const officer of side.officers) {
      officer.id ??= names.get(officer.name);
      assert.ok(officer.id, `${chapter.id}: unresolved extra officer ${officer.name}`);
      const troops = objects.filter(o => o.unit >= 27 && o.tail?.[0] === officer.id);
      assert.deepEqual(actualCounts(troops), sorted(officer.troops), `${chapter.id}: ${officer.name} members`);
      const members = sum(officer.troops);
      assert.ok(members <= 15, `${chapter.id}: team exceeds confirmed15 members`);
      if (members === 15) fullTeams++;
      total += members;
    }
    assert.equal(total, side.total, `${chapter.id}: troop total`);
    assert.equal(objects.filter(o => o.unit >= 27).length, total, `${chapter.id}: no extra troops`);
  }
}
const result = { schemaVersion: 1, source: 'docs/reference/level-openings.md', chapters, fullTeams };
const outputIndex = process.argv.indexOf('--output');
if (outputIndex >= 0) fs.writeFileSync(path.resolve(process.argv[outputIndex + 1]), JSON.stringify(result, null, 2) + '\n');
console.log(`OPENING DATA PASS ${chapters.length} maps / ${chapters.reduce((n, c) => n + c.sides.length, 0)} sides / ${fullTeams} full15-member teams / resources, ranks, identities, members and buildings`);
