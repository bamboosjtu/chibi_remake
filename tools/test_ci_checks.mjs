import assert from 'node:assert/strict';
import {runChecks} from './lib/ci_checks.mjs';
const visited = [];
const results = runChecks(['failed', 'spawn-error', 'signal', 'passed'].map(name => ({name})), check => {
  visited.push(check.name);
  if (check.name === 'spawn-error') throw Error('missing executable');
  return {status: check.name === 'failed' ? 1 : 0, signal: check.name === 'signal' ? 'SIGTERM' : null};
});
assert.equal(visited.length, 4, 'Failures must not skip later gates');
assert.deepEqual(results.map(result => result.ok), [false, false, false, true]);
console.log('CI AGGREGATION PASS nonzero / exception / signal / later check still runs');
