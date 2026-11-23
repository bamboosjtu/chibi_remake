#!/usr/bin/env node
// Architecture gate: dependency matrix + baseline check.
// New unbaselined edges or stale baseline entries fail the build.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { analyze, checkDependencies, printCycles } from './dependency_report.mjs';

const output = '_work/refactor/dependency-graph.json';
const summary = analyze();
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(summary, null, 2) + '\n');

console.log(`DEPENDENCY: ${summary.files} files, ${summary.edges} edges, ${summary.sccs.length} SCC, ${summary.violations.length} baseline edges`);
printCycles(summary);
const errors = checkDependencies(summary);
if (errors.length) {
  console.error('DEPENDENCY CHECK FAIL:\n' + errors.join('\n'));
  process.exit(1);
}
console.log('DEPENDENCY CHECK PASS');
