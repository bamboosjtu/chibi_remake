#!/usr/bin/env node
// Architecture gate: dependency matrix + baseline check.
// New unbaselined edges or stale baseline entries fail the build.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { analyze } from './dependency_report.mjs';

const output = '_work/refactor/dependency-graph.json';
const summary = analyze();
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(summary, null, 2) + '\n');

console.log(`DEPENDENCY: ${summary.files} files, ${summary.edges} edges, ${summary.sccs.length} SCC, ${summary.violations.length} baseline edges`);
if (summary.unbaselined.length) {
  console.error(`DEPENDENCY CHECK FAIL: ${summary.unbaselined.length} unbaselined edge(s)`);
  for (const v of summary.unbaselined.slice(0, 40)) console.error(`  ${v.fromPackage} -> ${v.toPackage} ${v.from}:${v.line} (${v.kind})`);
  process.exit(1);
}
if (summary.baseline.stale) {
  console.error(`DEPENDENCY CHECK FAIL: ${summary.baseline.stale} stale baseline edge(s)`);
  for (const b of summary.staleBaseline.slice(0, 40)) console.error(`  ${b.from} -> ${b.to} (${b.removeByStage || ''})`);
  process.exit(1);
}
console.log('DEPENDENCY CHECK PASS');
