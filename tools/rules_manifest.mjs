import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const root = 'godot/chibi_remake';
export const manifestPath = 'data/db/rules_manifest.json';
const bootstrap = 'app/battle/startup/bootstrap.gd';
const nativePath = 'tools/native/sim_math/sim_math.cpp';
const normalize = text => text.replaceAll('\r\n','\n');
const sha256 = text => crypto.createHash('sha256').update(text).digest('hex');

export function rulesManifestText(simulationFiles, read, nativeSource) {
  const native = JSON.parse(read('data/db/native_math.json'));
  if (native.sourceSignature !== sha256(normalize(nativeSource))) {
    throw Error('Native math source identity stale; rebuild with tools/native/sim_math/build.py');
  }
  const sources = [...simulationFiles, bootstrap].sort();
  const manifest = { schemaVersion: 1, files: Object.fromEntries(sources.map(file =>
    ['res://' + file, sha256(normalize(read(file).replace(/^\uFEFF/,''))) ])) };
  return JSON.stringify(manifest, null, 2) + '\n';
}

export function assertRulesManifest(expected, recorded) {
  if (recorded === undefined || normalize(recorded) !== expected) {
    throw Error('Effective simulation rules changed; review and run node tools/rules_manifest.mjs --write');
  }
}

function main() {
  const walk = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(entry => {
    const file = dir + '/' + entry.name;
    return entry.isDirectory() ? walk(file) : file.endsWith('.gd') ? [file] : [];
  });
  const read = file => fs.readFileSync(path.join(root, file), 'utf8');
  const sources = walk('simulation');
  const expected = rulesManifestText(sources, read, fs.readFileSync(nativePath, 'utf8'));
  const target = path.join(root, manifestPath);
  if (process.argv.includes('--write')) fs.writeFileSync(target, expected);
  else assertRulesManifest(expected, fs.existsSync(target) ? read(manifestPath) : undefined);
  console.log('RULES MANIFEST PASS ' + (sources.length + 1) + ' simulation sources / stable exported identity');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
