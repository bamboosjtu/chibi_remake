import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const directory = path.resolve('_work/native-write-tests');
fs.mkdirSync(directory, {recursive: true});
const fixture = fs.mkdtempSync(path.join(directory, 'case-'));
const gate = path.resolve('tools/native_write_check.mjs');
const source = 'tools/native/sim_math/sim_math.cpp';
const review = 'tools/inputs/native_write_review.json';
const ownership = 'tools/inputs/unit_schema_ownership.json';
const write = (file, value) => fs.writeFileSync(path.join(fixture, file), value);
const entry = {field: 'action_phase', owner: 'movement', writer: 'sim_math.cpp'};
const snapshot = (entries, header = {}) => write(review, JSON.stringify({schemaVersion: 1, source, entries, ...header}));
const run = (...args) => spawnSync(process.execPath, [gate, ...args], {cwd: fixture, encoding: 'utf8'});
const reject = expected => {
  const result = run();
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, expected);
};

fs.mkdirSync(path.join(fixture, 'tools/native/sim_math'), {recursive: true});
fs.mkdirSync(path.join(fixture, 'tools/inputs'), {recursive: true});
write(source, `struct Keys { StringName phase{"action_phase"}, other{"other"}; } k;
  if (u[k.other] == 1) {}
  // u[k.other] = 42;
  u[k.phase] += 1;
`);
write(ownership, JSON.stringify({fields: {action_phase: {owner: 'movement'}}}));
snapshot([entry]);
assert.equal(run().status, 0);
snapshot([{...entry, owner: 'scenario'}]);
reject(/MISMATCH action_phase/);
snapshot([{...entry, writer: 'other.cpp'}]);
reject(/MISMATCH action_phase/);
snapshot([entry, entry]);
reject(/Duplicate.*action_phase/);
snapshot([entry], {source: 'other.cpp'});
reject(/header/);
snapshot([{...entry, field: 'stale'}]);
reject(/NEW action_phase[\s\S]+STALE stale/);
assert.equal(run('--write').status, 0);
assert.equal(run().status, 0);
write(ownership, JSON.stringify({fields: {action_phase: {}}}));
reject(/lack a unit owner.*action_phase/);
console.log('NATIVE WRITE REVIEW PASS correct registration / comparison reads / wrong owner and writer / duplicates / stale / regeneration');
