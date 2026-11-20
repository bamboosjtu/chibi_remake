#!/usr/bin/env node
// Validates tools/inputs/battle_state_ownership.json against BattleState and
// BattleStateFields. Proxy properties must point at session.<field>; field
// policies must match BattleStateFields; the business owners are fixed for the
// known special cases (auto_control -> ai, selected -> commands, tile_* ->
// navigation, readonly/derived).

import fs from 'node:fs';
import process from 'node:process';

const OWNERS = new Set(['world', 'session', 'navigation', 'economy', 'production', 'technology', 'scenario', 'officers', 'commands', 'ai', 'cheats', 'units']);
const POLICIES = new Set(['INPUTS', 'RESET', 'RESTORED', 'OBJECTS', 'READ_ONLY']);

export function parseState(stateText) {
  const names = [...stateText.matchAll(/^var (\w+)/gm)].map((m) => m[1]);
  const blocks = stateText.split(/^var /m).slice(1);
  const proxies = {};
  for (const b of blocks) {
    const name = (b.match(/^(\w+)/) || [])[1];
    const backing = (b.match(/get:\s*return session\.(\w+)/) || [])[1];
    if (name && backing) proxies[name] = backing;
  }
  return { names, proxies };
}

export function parsePolicies(policyText) {
  const out = {};
  for (const key of POLICIES) {
    const m = policyText.match(new RegExp(`const ${key}\\s*:=\\s*\\[([\\s\\S]*?)\\]`));
    for (const x of m ? m[1].matchAll(/"(\w+)"/g) : []) out[x[1]] = key;
  }
  return out;
}

export function validateState(stateText, policyText, ownership) {
  const errors = [];
  const { names, proxies } = parseState(stateText);
  const policyOf = parsePolicies(policyText);
  if (ownership.fieldCount !== names.length) errors.push(`fieldCount ${ownership.fieldCount} != state ${names.length}`);
  const stateNames = new Set(names);
  const jsonNames = new Set(Object.keys(ownership.fields || {}));
  for (const n of stateNames) if (!jsonNames.has(n)) errors.push(`missing ownership for ${n}`);
  for (const n of jsonNames) if (!stateNames.has(n)) errors.push(`unexpected ownership field ${n}`);
  for (const name of names) {
    const o = ownership.fields?.[name];
    if (!o) continue;
    if (!OWNERS.has(o.owner)) errors.push(`${name}: invalid owner ${o.owner}`);
    if (!POLICIES.has(o.policy)) errors.push(`${name}: invalid policy ${o.policy}`);
    if (policyOf[name] !== o.policy) errors.push(`${name}: policy ${o.policy} != BattleStateFields ${policyOf[name] || 'UNCLASSIFIED'}`);
    if (proxies[name]) {
      if (o.kind !== 'proxy') errors.push(`${name}: expected kind proxy`);
      if (o.backing_store !== `session.${proxies[name]}`) errors.push(`${name}: backing_store ${o.backing_store} != session.${proxies[name]}`);
      if (o.persist !== false) errors.push(`${name}: proxy must not persist`);
    } else if (o.kind === 'proxy') {
      errors.push(`${name}: kind proxy but no session backing`);
    }
    if (o.kind === 'readonly' && o.persist) errors.push(`${name}: readonly must not persist`);
    if (o.kind === 'derived' && o.persist) errors.push(`${name}: derived must not persist`);
    if (o.kind === 'storage' && o.policy === 'RESET' && o.persist) errors.push(`${name}: RESET must not persist`);
    if (!o.backing_store) errors.push(`${name}: missing backing_store`);
    if (!Array.isArray(o.readers)) errors.push(`${name}: readers must be an array`);
  }
  if (ownership.fields?.auto_control && ownership.fields.auto_control.owner !== 'ai') errors.push('auto_control: owner must be ai');
  if (ownership.fields?.selected && ownership.fields.selected.owner !== 'commands') errors.push('selected: owner must be commands');
  for (const tile of ['tile_w', 'tile_hw', 'tile_hh']) {
    if (!ownership.fields?.[tile]) continue;
    if (ownership.fields[tile].kind !== 'readonly') errors.push(`${tile}: kind must be readonly`);
    if (ownership.fields[tile].owner !== 'navigation') errors.push(`${tile}: owner must be navigation`);
  }
  return { errors, count: names.length };
}

function main() {
  const args = process.argv.slice(2);
  const arg = (name, fallback) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback; };
  const statePath = arg('--state', 'godot/chibi_remake/simulation/state/battle_state.gd');
  const policyPath = arg('--policy', 'godot/chibi_remake/simulation/state/battle_state_fields.gd');
  const ownershipPath = arg('--ownership', 'tools/inputs/battle_state_ownership.json');
  for (const p of [statePath, policyPath, ownershipPath]) if (!fs.existsSync(p)) { console.error(`BATTLE STATE OWNERSHIP FAIL: missing ${p}`); process.exit(2); }
  const { errors, count } = validateState(
    fs.readFileSync(statePath, 'utf8'),
    fs.readFileSync(policyPath, 'utf8'),
    JSON.parse(fs.readFileSync(ownershipPath, 'utf8')),
  );
  if (errors.length) {
    console.error(`BATTLE STATE OWNERSHIP FAIL: ${errors.length} error(s)`);
    for (const e of errors.slice(0, 40)) console.error(`  ${e}`);
    process.exit(1);
  }
  console.log(`BATTLE STATE OWNERSHIP PASS: ${count} fields`);
}

if (process.argv[1]?.endsWith('battle_state_ownership_check.mjs')) main();
