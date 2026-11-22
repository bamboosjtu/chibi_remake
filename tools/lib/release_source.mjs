import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const project = 'godot/chibi_remake/';

export function isReleaseScript(relative) {
  return /\.(gd|tscn|tres|godot|gdextension)$/.test(relative) &&
    (!relative.includes('/') || /^(app|simulation|presentation|addons)\//.test(relative)) &&
    !relative.split('/').some(part => part.startsWith('.'));
}

export function readReleaseSnapshot(commit, cwd = process.cwd()) {
  if (!/^(?:[a-f0-9]{40}|[a-f0-9]{64})$/.test(commit)) throw Error('Release source requires a full Git commit ID');
  const git = (args, options) => execFileSync('git', args, { cwd, maxBuffer: 128 * 1024 * 1024, ...options });
  git(['cat-file', '-e', commit + '^{commit}']);
  const tree = git(['ls-tree', '-rz', '--full-tree', commit, '--', project], { encoding: 'utf8' });
  const entries = new Map();
  for (const row of tree.split('\0').filter(Boolean)) {
    const match = /^100(?:644|755) blob ([a-f0-9]+)\t([\s\S]+)$/.exec(row);
    if (match) entries.set(match[2].slice(project.length), match[1]);
  }
  if (!entries.size) throw Error('Release source commit has no Godot project');

  // Get the committed bytes in one batch. The Git objects for LFS assets are pointers.
  const ids = [...new Set(entries.values())];
  const batch = git(['cat-file', '--batch'], { input: ids.join('\n') + '\n' });
  const blobs = new Map();
  let offset = 0;
  for (const id of ids) {
    const end = batch.indexOf(10, offset);
    const header = batch.toString('ascii', offset, end);
    const size = Number(header.split(' ')[2]);
    const start = end + 1;
    if (!header.startsWith(id + ' blob ') || !Number.isSafeInteger(size) || size < 0 || batch[start + size] !== 10) {
      throw Error('Invalid Git object in release source: ' + id);
    }
    blobs.set(id, batch.subarray(start, start + size));
    offset = start + size + 1;
  }
  return new Map([...entries].map(([name, id]) => [name, blobs.get(id)]));
}

export function copyReleaseInput(snapshot, relative, workingFile, target) {
  const data = snapshot.get(relative);
  if (!data) throw Error('Release input is not tracked at the build commit: ' + relative);
  if (data.length <= 1024 && data.toString('utf8').startsWith('version https://git-lfs.github.com/spec/v1\n')) {
    const pointer = /^version https:\/\/git-lfs\.github\.com\/spec\/v1\noid sha256:([a-f0-9]{64})\nsize (\d+)\n?$/.exec(data.toString('utf8'));
    if (!pointer) throw Error('Invalid Git LFS pointer: ' + relative);
    fs.copyFileSync(workingFile, target);
    const materialized = fs.readFileSync(target);
    if (materialized.length !== Number(pointer[2]) || createHash('sha256').update(materialized).digest('hex') !== pointer[1]) {
      throw Error('Materialized release input differs from Git LFS pointer: ' + relative);
    }
    return;
  }
  fs.writeFileSync(target, data);
}

export function copyAcceptanceScripts(snapshot, source, destination) {
  if (fs.existsSync(destination)) throw Error('Use a new acceptance staging directory');
  fs.mkdirSync(destination, { recursive: true });
  if (!snapshot) {
    fs.cpSync(path.join(source, 'testing'), destination, { recursive: true });
    return;
  }
  for (const name of snapshot.keys()) {
    if (!name.startsWith('testing/') || !name.endsWith('.gd')) continue;
    const target = path.join(destination, name.slice('testing/'.length));
    fs.mkdirSync(path.dirname(target), { recursive: true });
    copyReleaseInput(snapshot, name, path.join(source, name), target);
  }
}
