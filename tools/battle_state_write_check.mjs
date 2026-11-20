#!/usr/bin/env node
// P6 write-ownership gate for BattleState fields.
//
// The ownership JSON names one target business owner per field. A writer in the
// owner's package is allowed; a writer in another package must be frozen in
// battle_state_write_baseline.json with a reason and removal stage. New
// cross-package writes fail, stale baseline entries fail. This intentionally
// gates new debt without rewriting the existing 37-field surface in one step.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const OWNER_PACKAGE = {
  world: 'simulation/world',
  session: 'simulation/session',
  navigation: 'simulation/navigation',
  economy: 'simulation/economy',
  production: 'simulation/production',
  technology: 'simulation/technology',
  scenario: 'simulation/scenario',
  officers: 'simulation/officers',
  commands: 'simulation/commands',
  ai: 'simulation/ai',
  cheats: 'simulation/cheats',
  units: 'simulation/units',
};

export function scan(root, ownership) {
  const fields = ownership.fields || {};
  const found = new Map();
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) { walk(full); continue; }
      if (!entry.name.endsWith('.gd')) continue;
      const rel = path.relative(root, full).replaceAll('\\', '/');
      const text = fs.readFileSync(full, 'utf8');
      for (const m of text.matchAll(/\b(?:battle|state|_state)\.(\w+)\s*(?:=|\+=|-=|\*=)/g)) {
        const field = m[1];
        if (!fields[field]) continue;
        const line = text.slice(0, m.index).split('\n').length;
        const key = `${rel}\u0000${field}`;
        if (!found.has(key)) found.set(key, { file: rel, field, line, owner: fields[field].owner });
      }
      for (const m of text.matchAll(/\.set\(\s*["'](\w+)["']/g)) {
        const field = m[1];
        if (!fields[field]) continue;
        const line = text.slice(0, m.index).split('\n').length;
        const key = `${rel}\u0000${field}`;
        if (!found.has(key)) found.set(key, { file: rel, field, line, owner: fields[field].owner });
      }
    }
  };
  for (const layer of ['simulation', 'app', 'presentation']) {
    const dir = path.join(root, layer);
    if (fs.existsSync(dir)) walk(dir);
  }
  return [...found.values()].sort((a, b) => a.file.localeCompare(b.file) || a.field.localeCompare(b.field));
}

function packageOf(file) {
  const parts = file.split('/');
  return parts.length >= 2 ? parts.slice(0, 2).join('/') : parts[0];
}

export function evaluate(root, ownership, baseline) {
  const writes = scan(root, ownership);
  const allowed = [];
  const violations = [];
  for (const w of writes) {
    const ownerPkg = OWNER_PACKAGE[w.owner] || `simulation/${w.owner}`;
    const writerPkg = packageOf(w.file);
    if (writerPkg === ownerPkg || writerPkg === 'simulation/world' || w.file.endsWith('snapshot_restorer.gd')) {
      allowed.push(w);
    } else {
      violations.push(w);
    }
  }
  const entries = baseline.entries || [];
  const matched = new Set();
  const unbaselined = [];
  for (const v of violations) {
    const hit = entries.find((e) => !matched.has(e) && e.file === v.file && e.field === v.field);
    if (hit) matched.add(hit); else unbaselined.push(v);
  }
  const stale = entries.filter((e) => !matched.has(e));
  return { writes, allowed, violations, unbaselined, stale };
}

function main() {
  const args = process.argv.slice(2);
  const arg = (name, fallback) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback; };
  const root = arg('--root', 'godot/chibi_remake');
  const ownershipPath = arg('--ownership', 'tools/inputs/battle_state_ownership.json');
  const baselinePath = arg('--baseline', 'tools/inputs/battle_state_write_baseline.json');
  const write = args.includes('--write');
  const ownership = JSON.parse(fs.readFileSync(ownershipPath, 'utf8'));
  if (write) {
    const result = evaluate(root, ownership, { entries: [] });
    const entries = result.violations.map((v) => ({
      file: v.file, field: v.field, line: v.line,
      reason: `Current cross-package writer (${packageOf(v.file)} writes ${v.owner} field)`,
      removeByStage: 'P7',
    }));
    fs.writeFileSync(baselinePath, JSON.stringify({ schemaVersion: 1, entries }, null, 2) + '\n');
    console.log(`BATTLE STATE WRITE BASELINE WRITE ${entries.length} entries`);
    return;
  }
  const baseline = fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, 'utf8')) : { entries: [] };
  const result = evaluate(root, ownership, baseline);
  console.log(`BATTLE STATE WRITE: ${result.writes.length} writes, ${result.allowed.length} owner-package, ${result.violations.length} cross-package, ${result.unbaselined.length} new, ${result.stale.length} stale`);
  for (const v of result.unbaselined.slice(0, 40)) console.error(`  NEW ${v.file}:${v.line} writes ${v.field} owned by ${v.owner}`);
  for (const s of result.stale.slice(0, 40)) console.error(`  STALE ${s.file} ${s.field}`);
  if (result.unbaselined.length || result.stale.length) process.exit(1);
  console.log('BATTLE STATE WRITE PASS');
}

if (process.argv[1]?.endsWith('battle_state_write_check.mjs')) main();
