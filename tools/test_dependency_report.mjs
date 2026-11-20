#!/usr/bin/env node
// Positive/negative fixtures for tools/dependency_report.mjs and the baseline gate.
// Runs in a temporary tree under _work and never touches project sources.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { analyze } from './dependency_report.mjs';

const base = path.resolve('_work', `test-dependency-${process.pid}`);
fs.rmSync(base, { recursive: true, force: true });
fs.mkdirSync(path.join(base, 'simulation/movement'), { recursive: true });
fs.mkdirSync(path.join(base, 'simulation/navigation'), { recursive: true });
fs.mkdirSync(path.join(base, 'presentation'), { recursive: true });
fs.mkdirSync(path.join(base, 'app'), { recursive: true });

const write = (rel, text) => fs.writeFileSync(path.join(base, rel), text);
write('simulation/navigation/n.gd', 'extends RefCounted\n');
write('simulation/movement/m.gd', 'extends RefCounted\nconst N = preload("res://simulation/navigation/n.gd")\n');
write('presentation/bad.gd', 'extends RefCounted\n');
write('app/bad.gd', 'extends RefCounted\n');

const entries = [
  ['simulation/movement/m.gd', 'simulation/movement/m.gd', 'simulation/movement'],
  ['simulation/navigation/n.gd', 'simulation/navigation/n.gd', 'simulation/navigation'],
  ['presentation/bad.gd', 'presentation/bad.gd', 'presentation'],
  ['app/bad.gd', 'app/bad.gd', 'app'],
];
fs.writeFileSync(path.join(base, 'map.json'), JSON.stringify({
  sourceFiles: entries.length,
  entries: entries.map(([from, to, pkg]) => ({ from, to, package: pkg, status: 'retained' })),
}));
const matrix = {
  schemaVersion: 1,
  packages: {
    root: { allow: ['*'] },
    testing: { allow: ['*'] },
    'simulation/movement': { allow: ['simulation/navigation', 'root'] },
    'simulation/navigation': { allow: ['root'] },
    presentation: { allow: ['presentation', 'root'] },
    app: { allow: ['app', 'root'] },
  },
  fileExceptions: [],
};
fs.writeFileSync(path.join(base, 'matrix.json'), JSON.stringify(matrix));
fs.writeFileSync(path.join(base, 'baseline-empty.json'), JSON.stringify({ edges: [] }));

function run(extra, name) {
  if (extra) write('simulation/movement/extra.gd', extra);
  return analyze({
    root: base,
    map: path.join(base, 'map.json'),
    matrix: path.join(base, 'matrix.json'),
    baseline: path.join(base, 'baseline.json'),
  });
}

const errors = [];
const check = (name, cond, detail) => { if (!cond) errors.push(`${name}: ${detail || 'failed'}`); };

// 1. Legal edge passes.
let r = run(null, 'legal');
check('legal', r.unbaselined.length === 0, `${r.unbaselined.length} unbaselined`);

// 2. Illegal cross-package edge fails.
r = run('extends RefCounted\nconst B = preload("res://presentation/bad.gd")\n', 'illegal');
check('illegal', r.unbaselined.length === 1 && r.unbaselined[0].toPackage === 'presentation', `got ${JSON.stringify(r.unbaselined.map((x) => x.toPackage))}`);

// 3. The same edge passes once recorded in the baseline.
fs.writeFileSync(path.join(base, 'baseline.json'), JSON.stringify({
  edges: [{ from: 'simulation/movement/extra.gd', to: 'presentation/bad.gd', fromPackage: 'simulation/movement', toPackage: 'presentation', reason: 'fixture', removeByStage: 'P5' }],
}));
r = run(null, 'baselined');
check('baselined', r.unbaselined.length === 0 && r.baseline.stale === 0, `${r.unbaselined.length} unbaselined, ${r.baseline.stale} stale`);

// 4. Stale baseline entries fail.
fs.writeFileSync(path.join(base, 'baseline.json'), JSON.stringify({
  edges: [{ from: 'simulation/movement/gone.gd', to: 'presentation/gone.gd', reason: 'fixture', removeByStage: 'P5' }],
}));
r = run(null, 'stale');
check('stale', r.baseline.stale === 1, `stale ${r.baseline.stale}`);

// 5. File-level allow list accepts the named target.
fs.writeFileSync(path.join(base, 'matrix.json'), JSON.stringify({
  ...matrix,
  packages: { ...matrix.packages, 'simulation/movement': { allow: ['simulation/navigation', 'root'], allowFiles: ['presentation/bad.gd'] } },
}));
fs.writeFileSync(path.join(base, 'baseline.json'), JSON.stringify({ edges: [] }));
r = run(null, 'allowFiles');
check('allowFiles', r.unbaselined.length === 0, `${r.unbaselined.length} unbaselined`);

fs.rmSync(base, { recursive: true, force: true });
if (errors.length) {
  console.error(`DEPENDENCY TESTS FAIL: ${errors.length}`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('DEPENDENCY TESTS PASS: 5 cases');
