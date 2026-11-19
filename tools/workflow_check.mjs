#!/usr/bin/env node
// The hosted workflow is code: it must not point at scripts, inputs, actions or
// matrix values that no longer exist, and every job needs a timeout. This gate
// runs inside `contracts`, so a stale workflow fails before it burns runner time.
import fs from 'node:fs';
import path from 'node:path';

const workflowDir = '.github/workflows';
const files = fs.readdirSync(workflowDir).filter(file => file.endsWith('.yml') || file.endsWith('.yaml'));
const errors = [];
if (files.length !== 1) {
  errors.push(`expected exactly one workflow, found ${files.length}: ${files.join(', ') || 'none'}`);
  console.error(errors.join('\n'));
  process.exit(1);
}

const name = files[0];
const source = fs.readFileSync(path.join(workflowDir, name), 'utf8').replace(/\r\n/g, '\n');
const exists = relative => fs.existsSync(relative);

for (const match of source.matchAll(/node\s+(tools\/[\w./-]+\.mjs)/g)) {
  if (!exists(match[1])) errors.push(`${name}: missing script ${match[1]}`);
}
for (const match of source.matchAll(/tools\/inputs\/[\w.-]+\.json/g)) {
  if (!exists(match[0])) errors.push(`${name}: missing input ${match[0]}`);
}
for (const match of source.matchAll(/uses:\s+(\.\/[^\s]+)/g)) {
  const target = match[1];
  if (!exists(target) && !exists(path.join(target, 'action.yml'))) errors.push(`${name}: missing local action ${target}`);
}
for (const match of source.matchAll(/source\/[\w./-]+\.png/g)) {
  if (!exists(match[0])) errors.push(`${name}: missing LFS fixture ${match[0]}`);
}
for (const retired of ['contracts.yml', 'release-regressions.yml']) {
  if (source.includes(retired)) errors.push(`${name}: references removed workflow ${retired}`);
}

const jobsStart = source.indexOf('\njobs:');
const jobsSection = jobsStart < 0 ? '' : source.slice(jobsStart);
const jobs = [...jobsSection.matchAll(/^  ([a-z][\w-]*):$/gm)].map(match => match[1]);
if (!jobs.length) errors.push(`${name}: no jobs found`);
for (const [index, job] of jobs.entries()) {
  const start = jobsSection.indexOf(`\n  ${job}:`);
  const next = jobs[index + 1];
  const end = next ? jobsSection.indexOf(`\n  ${next}:`) : jobsSection.length;
  const block = jobsSection.slice(start, end);
  if (!/runs-on:/.test(block)) errors.push(`${job}: missing runs-on`);
  if (!/timeout-minutes:/.test(block)) errors.push(`${job}: missing timeout-minutes`);
}

// The continuation matrix must stay inside the maps the tool actually supports.
const matrix = source.match(/matrix:\s*\n\s+map:\s*\[([^\]]+)\]/);
if (matrix) {
  const declared = matrix[1].split(',').map(value => value.trim()).filter(Boolean).sort();
  const tool = fs.readFileSync('tools/test_continuation_coverage.mjs', 'utf8');
  const supported = (tool.match(/const maps=\[([^\]]+)\]/)?.[1] ?? '')
    .split(',').map(value => value.replace(/['"\s]/g, '')).filter(Boolean).sort();
  if (JSON.stringify(declared) !== JSON.stringify(supported)) {
    errors.push(`continuation matrix [${declared}] differs from supported maps [${supported}]`);
  }
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`WORKFLOW PASS ${name} / ${jobs.length} jobs / timeouts, matrix and references resolve`);
}
