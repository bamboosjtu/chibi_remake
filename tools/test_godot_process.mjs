import assert from 'node:assert/strict';
import path from 'node:path';
import {runGodot} from './lib/godot_process.mjs';

const run = (name, code, options = {}) => runGodot({engine: process.execPath,
  args: ['--input-type=module', '-e', code], directory: '_work/process-runner-tests', name, ...options});
assert.ok((await run('success', 'console.log("PASS")', {markers: ['PASS']})).ok);
assert.equal((await run('exit', 'process.exit(2)')).ok, false);
assert.equal((await run('missing-marker', 'console.log("other")', {markers: ['PASS']})).ok, false);
assert.equal((await run('script-error', 'console.error("SCRIPT ERROR: test");setInterval(()=>{},1000)')).ok, false);
const environment = await run('profile-env', 'console.log(JSON.stringify({APPDATA:process.env.APPDATA,LOCALAPPDATA:process.env.LOCALAPPDATA,XDG_DATA_HOME:process.env.XDG_DATA_HOME,XDG_CACHE_HOME:process.env.XDG_CACHE_HOME,XDG_CONFIG_HOME:process.env.XDG_CONFIG_HOME}))');
assert.ok(environment.ok);
const profile = path.resolve('_work/process-runner-tests/profile-env-profile');
assert.deepEqual(JSON.parse(environment.output.trim()), {APPDATA:profile,LOCALAPPDATA:profile,
  XDG_DATA_HOME:path.join(profile,'data'),XDG_CACHE_HOME:path.join(profile,'cache'),XDG_CONFIG_HOME:path.join(profile,'config')});
const timeout = await run('timeout', 'setInterval(()=>{},1000)', {timeout: 0.1});
assert.ok(timeout.timedOut && !timeout.ok && timeout.seconds < 5);
console.log('ENGINE PROCESS PASS exit / markers / script errors / deadline / process termination / Windows and XDG profile isolation');
