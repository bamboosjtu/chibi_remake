import fs from 'node:fs';
import {execFileSync, spawnSync} from 'node:child_process';

const tracked = execFileSync('git', ['ls-files', '-z'], {encoding: 'buffer', maxBuffer: 64 * 1024 * 1024})
  .toString('utf8')
  .split('\0')
  .filter(Boolean);
const failures = [];

const scripts = tracked.filter((file) => /\.(mjs|js)$/.test(file));
for (const file of scripts) {
  const result = spawnSync(process.execPath, ['--check', file], {encoding: 'utf8'});
  if (result.status !== 0) {
    failures.push(file + ': ' + (result.stderr || result.stdout).trim().split('\n').slice(0, 3).join(' | '));
  }
}

const jsonFiles = tracked.filter((file) => file.toLowerCase().endsWith('.json'));
for (const file of jsonFiles) {
  try {
    JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  } catch (error) {
    failures.push(file + ': ' + error.message);
  }
}

if (failures.length > 0) {
  for (const failure of failures) console.error('SYNTAX FAIL ' + failure);
  process.exit(1);
}
console.log('SYNTAX PASS js=' + scripts.length + ' json=' + jsonFiles.length);
