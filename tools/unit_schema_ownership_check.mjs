#!/usr/bin/env node
// Validates tools/inputs/unit_schema_ownership.json against UnitSchema.FIELDS.
// The JSON must cover every field exactly once, with a unique owner and the
// same persist/derived flags as the GDScript schema.

import fs from 'node:fs';
import process from 'node:process';

const OWNERS = new Set(['units', 'movement', 'navigation', 'combat', 'visibility', 'officers', 'commands', 'economy', 'construction', 'transport', 'technology']);

export function validateUnit(schemaText, ownership) {
  const errors = [];
  const fields = [];
  for (const m of schemaText.matchAll(/^\s*"(\w+)":\s*\{([^}]*)\}/gm)) {
    fields.push({
      name: m[1],
      persist: /"persist":\s*true/.test(m[2]),
      derived: /"derived":\s*true/.test(m[2]),
    });
  }
  const seen = new Map();
  for (const f of fields) seen.set(f.name, (seen.get(f.name) || 0) + 1);
  for (const [name, count] of seen) if (count > 1) errors.push(`duplicate schema field ${name} (${count})`);
  if (ownership.fieldCount !== fields.length) errors.push(`fieldCount ${ownership.fieldCount} != schema ${fields.length}`);
  const names = new Set(fields.map((f) => f.name));
  const jsonNames = new Set(Object.keys(ownership.fields || {}));
  for (const n of names) if (!jsonNames.has(n)) errors.push(`missing ownership for ${n}`);
  for (const n of jsonNames) if (!names.has(n)) errors.push(`unexpected ownership field ${n}`);
  for (const f of fields) {
    const o = ownership.fields?.[f.name];
    if (!o) continue;
    if (!OWNERS.has(o.owner)) errors.push(`${f.name}: invalid owner ${o.owner}`);
    if (o.persist !== f.persist) errors.push(`${f.name}: persist ${o.persist} != schema ${f.persist}`);
    if (o.derived !== f.derived) errors.push(`${f.name}: derived ${o.derived} != schema ${f.derived}`);
    if (o.backing_store !== `unit.${f.name}`) errors.push(`${f.name}: backing_store ${o.backing_store}`);
    if (!o.lifecycle) errors.push(`${f.name}: missing lifecycle`);
    if (!Array.isArray(o.readers)) errors.push(`${f.name}: readers must be an array`);
    if (f.derived && o.derived_by !== o.owner) errors.push(`${f.name}: derived_by ${o.derived_by} != owner ${o.owner}`);
  }
  return { errors, count: fields.length };
}

function main() {
  const args = process.argv.slice(2);
  const arg = (name, fallback) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback; };
  const schemaPath = arg('--schema', 'godot/chibi_remake/simulation/definitions/unit_schema.gd');
  const ownershipPath = arg('--ownership', 'tools/inputs/unit_schema_ownership.json');
  for (const p of [schemaPath, ownershipPath]) if (!fs.existsSync(p)) { console.error(`UNIT OWNERSHIP FAIL: missing ${p}`); process.exit(2); }
  const { errors, count } = validateUnit(fs.readFileSync(schemaPath, 'utf8'), JSON.parse(fs.readFileSync(ownershipPath, 'utf8')));
  if (errors.length) {
    console.error(`UNIT OWNERSHIP FAIL: ${errors.length} error(s)`);
    for (const e of errors.slice(0, 40)) console.error(`  ${e}`);
    process.exit(1);
  }
  console.log(`UNIT OWNERSHIP PASS: ${count} fields`);
}

if (process.argv[1]?.endsWith('unit_schema_ownership_check.mjs')) main();
