import assert from 'node:assert/strict';
import {runGodot} from './lib/godot_process.mjs';

const run = (name, code, options = {}) => runGodot({engine: process.execPath,
  args: ['--input-type=module', '-e', code], directory: '_work/process-runner-tests', name, ...options});
assert.ok((await run('success', 'console.log("PASS")', {markers: ['PASS']})).ok);
assert.equal((await run('exit', 'process.exit(2)')).ok, false);
assert.equal((await run('missing-marker', 'console.log("other")', {markers: ['PASS']})).ok, false);
assert.equal((await run('script-error', 'console.error("SCRIPT ERROR: test");setInterval(()=>{},1000)')).ok, false);
const timeout = await run('timeout', 'setInterval(()=>{},1000)', {timeout: 0.1});
assert.ok(timeout.timedOut && !timeout.ok && timeout.seconds < 5);
console.log('ENGINE PROCESS PASS exit / markers / script errors / deadline / process termination');
