import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { copyAcceptanceScripts, copyReleaseInput, isReleaseScript, readReleaseSnapshot } from './lib/release_source.mjs';

const parent = path.resolve('_work');
fs.mkdirSync(parent, { recursive: true });
const fixture = fs.mkdtempSync(path.join(parent, 'release-source-'));
const project = 'godot/chibi_remake/';
const rulesTool = path.resolve('tools/rules_manifest.mjs');
const write = (relative, contents) => {
  const target = path.join(fixture, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, contents);
  return target;
};
const git = (...args) => execFileSync('git', args, { cwd: fixture, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const sha256 = contents => createHash('sha256').update(contents).digest('hex');
const rules = (...args) => spawnSync(process.execPath, [rulesTool, ...args], { cwd: fixture, encoding: 'utf8' });

try {
  const originalAsset = 'materialized input';
  git('init', '-q');
  write('.gitignore', 'godot/chibi_remake/art/production/references/\n');
  const script = write(project + 'app/runtime.gd', 'extends RefCounted\n');
  write(project + 'testing/automation/probe.gd', 'extends SceneTree\n');
  const asset = write(project + 'assets/runtime.png',
    'version https://git-lfs.github.com/spec/v1\noid sha256:' + sha256(originalAsset) + '\nsize ' + originalAsset.length + '\n');
  git('add', '--', '.');
  git('-c', 'user.name=Release fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Fixture source');
  const commit = git('rev-parse', 'HEAD');
  fs.writeFileSync(script, 'modified working copy');
  fs.writeFileSync(asset, originalAsset);
  write(project + 'app/untracked.gd', 'untracked');
  write(project + 'art/production/references/local.gd', 'ignored');

  const snapshot = readReleaseSnapshot(commit, fixture);
  assert.deepEqual([...snapshot.keys()].filter(isReleaseScript), ['app/runtime.gd']);
  assert.equal(isReleaseScript('art/production/references/local.gd'), false);
  const staged = path.join(fixture, 'staged.gd');
  copyReleaseInput(snapshot, 'app/runtime.gd', script, staged);
  assert.equal(fs.readFileSync(staged, 'utf8'), 'extends RefCounted\n');
  const materialized = path.join(fixture, 'staged.png');
  copyReleaseInput(snapshot, 'assets/runtime.png', asset, materialized);
  assert.equal(fs.readFileSync(materialized, 'utf8'), originalAsset);
  fs.writeFileSync(asset, 'different bytes');
  assert.throws(() => copyReleaseInput(snapshot, 'assets/runtime.png', asset, materialized), /differs from Git LFS pointer/);
  const companion = path.join(fixture, 'companion');
  copyAcceptanceScripts(snapshot, path.join(fixture, project), companion);
  assert.equal(fs.readFileSync(path.join(companion, 'automation/probe.gd'), 'utf8'), 'extends SceneTree\n');

  const native = 'fixture native source\n';
  write('tools/native/sim_math/sim_math.cpp', native);
  write(project + 'data/db/native_math.json', JSON.stringify({ sourceSignature: sha256(native) }));
  write(project + 'simulation/runtime.gd', 'extends RefCounted\n');
  const bootstrap = write(project + 'app/battle/startup/bootstrap.gd', 'extends RefCounted\n');
  const generated = rules('--write');
  assert.equal(generated.status, 0, generated.stderr);
  const manifest = path.join(fixture, project, 'data/db/rules_manifest.json');
  fs.writeFileSync(manifest, fs.readFileSync(manifest, 'utf8').replaceAll('\n', '\r\n'));
  const crlf = rules('--check');
  assert.equal(crlf.status, 0, crlf.stderr);
  fs.appendFileSync(bootstrap, 'const RULE = 1\n');
  assert.match(rules('--check').stderr, /Effective simulation rules changed/);
  console.log('RELEASE SOURCE PASS pinned scripts and companion / Git LFS bytes / ignored paths / CRLF manifest');
} finally {
  assert.equal(path.dirname(fixture), parent);
  fs.rmSync(fixture, { recursive: true, force: true });
}
