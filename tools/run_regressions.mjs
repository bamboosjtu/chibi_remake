import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {runGodot} from './lib/godot_process.mjs';
import {matchesKnownFailure} from './lib/regression_result.mjs';

const args = process.argv.slice(2);
const value = (key, fallback) => args.includes(key) ? args[args.indexOf(key) + 1] : fallback;
const engine = path.resolve(value('--engine', 'Godot_v4.7.2-stable_win64.exe'));
const project = path.resolve(value('--project', 'godot/chibi_remake'));
const pack = value('--pack');
// Export templates can disable path overrides. Exercise the shipped EXE via
// its own adjacent PCK and normal menu startup; debug engines can mount a pack.
const native = args.includes('--native');
if (native && pack) throw new Error('--native uses the executable\'s adjacent PCK; do not pass --pack');
if (native && args.includes('--suite')) throw new Error('Script suites require an assertion-enabled engine, not --native');
const targetArgs = native ? [] : pack ? ['--main-pack', path.resolve(pack)] : ['--path', project];
const battleScene = native ? [] : ['res://main.tscn'];
const scripts = path.resolve(value('--scripts', 'tools/gd'));
const directory = path.resolve(value('--output', '_work/regressions'));
const jobs = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--suite') {
    const suite = JSON.parse(fs.readFileSync(args[++i], 'utf8'));
    for (const test of suite.tests) jobs.push({name: test.script, markers: test.markers, expectedFailure: test.expectedFailure, fixture: test.fixture,
      timeout: test.timeout ?? 120,
      args: ['--headless', ...targetArgs, '--script', path.join(scripts, test.script + '.gd'), '--', '--no-intro', ...(test.args ?? [])]});
  }
}
if (args.includes('--selftests')) for (const map of ['chibic1', 'chibil1', 'chibic17']) jobs.push({
  name: 'selftest-' + map, markers: ['SELFTEST RESULT: PASS'],
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + map, '--selftest']});
if (args.includes('--selftest-failures')) {
  for (const [fault, label] of [['write', '阵亡快照写入成功'], ['read', '阵亡快照主档可读']]) {
    jobs.push({
      name: 'selftest-failure-' + fault, markers: ['SELFTEST RESULT: FAIL', 'FAIL  ' + label], expectSelftestFailure: true,
      args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=chibic1', '--selftest', '--selftest-fault=' + fault],
    });
  }
}
const baseline = JSON.parse(fs.readFileSync('tools/inputs/baselines.json', 'utf8'));
if (args.includes('--baselines')) for (const test of baseline.simtest) jobs.push({
  name: `sim-${test.map}-${test.seconds}`, baseline: test,
  timeout: 600,
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + test.map, '--simtest=' + test.seconds]});
if (args.includes('--require-native-world')) jobs.push({
  name: 'test_native_world', markers: ['NATIVE WORLD PASS'], timeout: 300,
  args: ['--headless', ...targetArgs, '--script', path.join(scripts, 'test_native_world.gd'), '--', '--no-intro', '--noview'],
});
if (args.includes('--maps')) for (const file of fs.readdirSync(project + '/data').filter(f => /^chibi.*\.json$/.test(f))) jobs.push({
  name: 'load-' + file.slice(0, -5), markers: ['ARCH-013: view=false'],
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + file.slice(0, -5), '--noview', '--smoketest']});
if (!jobs.length) throw new Error('Specify --suite <json>, --selftests, --selftest-failures, --baselines or --maps');
const results = [];
for (const job of jobs) {
	// Portable markers override APPDATA; every regression also needs a save
	// namespace so testing an installed EXE/PCK cannot touch player slots.
	job.args.push('--save-test-id=regression-'+crypto.randomUUID());
  let result;
  if (job.fixture) {
    if (job.fixture !== 'opening-forces') throw Error('Unknown regression fixture: ' + job.fixture);
    fs.mkdirSync(directory, {recursive:true});
    const fixture = path.join(directory, job.name + '-fixture.json');
    const prepared = spawnSync(process.execPath, ['tools/test_opening_forces.mjs', '--output', fixture], {encoding:'utf8'});
    if (prepared.status !== 0 || prepared.error) {
      const output = (prepared.stdout ?? '') + (prepared.stderr ?? '') + (prepared.error?.message ?? '');
      const log = path.join(directory, job.name + '-fixture.log'); fs.writeFileSync(log, output);
      result = {name:job.name, ok:false, code:prepared.status, timedOut:false, missing:['fixture preparation'], seconds:0, log, output};
    } else job.args.push('--opening-fixture=' + fixture);
  }
  result ??= await runGodot({engine, directory, ...job});
  if (!result.ok && job.expectedFailure && !result.timedOut) {
    result.knownFailure = matchesKnownFailure(result.output, job.expectedFailure);
  }
  if (job.baseline) {
    const expected = job.baseline;
    const match = result.output.match(/SIMTEST: .*tick=(\d+) digest=(-?\d+)/);
    const sections = result.output.match(/SIMULATION DIGESTS: (.*)/);
    result.ok &&= !!match && Number(match[1]) === expected.tick && match[2] === expected.digest;
    if (expected.subsystems) {
      const actual = sections ? JSON.parse(sections[1]) : {};
      result.ok &&= Object.entries(expected.subsystems).every(([key, digest]) => actual[key] === digest);
    }
    if (expected.full) {
      result.ok &&= result.output.match(/SIMULATION FULL DIGEST: ([a-f0-9]{64})/)?.[1] === expected.full;
    }
  }
  const {output, ...summary} = result;
  results.push(summary);
  fs.writeFileSync(path.join(directory, 'results.json'), JSON.stringify(results, null, 2) + '\n');
  console.log(`${result.ok ? 'PASS' : result.knownFailure ? 'KNOWN FAILURE' : 'FAIL'} ${job.name} (${result.seconds.toFixed(1)}s) ${result.log}`);
}
if (results.some(result => !result.ok && !result.knownFailure)) process.exitCode = 1;
