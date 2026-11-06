import fs from 'node:fs';
import assert from 'node:assert/strict';
import {validate} from './lib/data_schema.mjs';
const root = 'godot/chibi_remake/data';
const schema = JSON.parse(fs.readFileSync('tools/inputs/schema/content.json', 'utf8'));
const read = file => JSON.parse(fs.readFileSync(root + '/' + file, 'utf8'));
for (const [file, contract] of [['db/unit_definitions.json', 'canonicalCatalog'], ['db/production_units.json', 'catalog']]) {
  const catalog = read(file);
  validate(schema.$defs[contract], catalog, schema, file);
  for (const key of Object.keys(catalog.units)) if (!/^\d+$/.test(key)) throw new Error(file + ': invalid unit ID ' + key);
}
const maps = fs.readdirSync(root).filter(file => /^chibi.*\.json$/.test(file));
for (const file of maps) {
  const level = read(file);
  validate(schema.$defs.level, level, schema, file);
  for (const field of ['walkable','terrainWalkable','waterWalkable']) if (level[field].length !== level.rows * level.cols) throw new Error(file + ': invalid ' + field + ' grid');
  for (const object of level.objects) if (!level.units[String(object.unit)]) throw new Error(file + ': object has no unit definition: ' + object.unit);
}
const bad = structuredClone(read('db/unit_definitions.json'));
delete bad.units['30'].hp;
assert.throws(() => validate(schema.$defs.catalog, bad, schema), /missing hp/);
bad.units['30'].hp = '100';
assert.throws(() => validate(schema.$defs.catalog, bad, schema), /expected number/);
bad.units['30'].hp = 100; bad.units['30'].costs = [-1, 2, 3];
assert.throws(() => validate(schema.$defs.catalog, bad, schema), /bounds/);
bad.units['30'].costs = [1, 2];
assert.throws(() => validate(schema.$defs.catalog, bad, schema), /length/);
console.log(`DATA CONTRACTS PASS 2 unit catalogs / ${maps.length} levels / malformed attributes and costs rejected`);
