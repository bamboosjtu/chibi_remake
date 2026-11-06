import fs from 'node:fs';
import path from 'node:path';
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
    for (const test of suite.tests) jobs.push({name: test.script, markers: test.markers, expectedFailure: test.expectedFailure,
      timeout: test.timeout ?? 120,
      args: ['--headless', ...targetArgs, '--script', path.join(scripts, test.script + '.gd'), '--', '--no-intro', ...(test.args ?? [])]});
  }
}
if (args.includes('--selftests')) for (const map of ['chibic1', 'chibil1', 'chibic17']) jobs.push({
  name: 'selftest-' + map, markers: ['SELFTEST RESULT: PASS'],
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + map, '--selftest']});
const baseline = JSON.parse(fs.readFileSync('tools/inputs/baselines.json', 'utf8'));
if (args.includes('--baselines')) for (const test of baseline.simtest) jobs.push({
  name: `sim-${test.map}-${test.seconds}`, baseline: test,
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + test.map, '--simtest=' + test.seconds]});
if (args.includes('--maps')) for (const file of fs.readdirSync(project + '/data').filter(f => /^chibi.*\.json$/.test(f))) jobs.push({
  name: 'load-' + file.slice(0, -5), markers: ['ARCH-013: view=false'],
  args: ['--headless', ...targetArgs, ...battleScene, '--', '--no-intro', '--map=' + file.slice(0, -5), '--noview', '--smoketest']});
if (!jobs.length) throw new Error('Specify --suite <json>, --selftests, --baselines or --maps');
const results = [];
for (const job of jobs) {
  const result = await runGodot({engine, directory, ...job});
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
  }
  const {output, ...summary} = result;
  results.push(summary);
  fs.writeFileSync(path.join(directory, 'results.json'), JSON.stringify(results, null, 2) + '\n');
  console.log(`${result.ok ? 'PASS' : result.knownFailure ? 'KNOWN FAILURE' : 'FAIL'} ${job.name} (${result.seconds.toFixed(1)}s) ${result.log}`);
}
if (results.some(result => !result.ok && !result.knownFailure)) process.exitCode = 1;
