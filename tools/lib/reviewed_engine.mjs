import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const lock = JSON.parse(fs.readFileSync(new URL('../inputs/engines.json', import.meta.url), 'utf8'));
const names = {
  win32: 'Godot_v4.7.2-stable_win64.exe',
  linux: 'Godot_v4.7.2-stable_linux.x86_64',
};

export function resolveEngine(root) {
  if (process.env.CHIBI_GODOT_ENGINE) return path.resolve(root, process.env.CHIBI_GODOT_ENGINE);
  const command = process.platform === 'win32' ? 'godot.exe' : 'godot';
  const candidates = [
    path.join(root, names[process.platform] ?? command),
    ...String(process.env.PATH ?? '').split(path.delimiter).filter(Boolean)
      .map(directory => path.resolve(root, directory.replace(/^"|"$/g, ''), command)),
  ];
  const engine = candidates.find(file => fs.statSync(file, {throwIfNoEntry:false})?.isFile());
  if (!engine) throw new Error('Missing reviewed Godot engine. Set CHIBI_GODOT_ENGINE or install ' + candidates[0]);
  return engine;
}

export function verifyEngine(engine, platform = process.platform) {
  const expected = lock.sha256[platform];
  if (!expected) throw new Error('No reviewed engine hash for ' + platform);
  const actual = crypto.createHash('sha256').update(fs.readFileSync(engine)).digest('hex');
  if (actual !== expected) {
    throw new Error('Engine differs from the reviewed ' + lock.version + ' bytes; expected ' + expected + ', actual ' + actual);
  }
  return 'ENGINE INTEGRITY PASS ' + platform + ' / ' + lock.version + ' / ' + actual;
}
