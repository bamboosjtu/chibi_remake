import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

/** Deduplicate the compiled transport bytes; source art and decoded pixels stay intact. */
export function dedupeTerrain(directory) {
  const stage = fs.realpathSync(directory);
  const base = 'art/full/terrain_chunks/';
  const resolve = relative => {
    if (!relative.startsWith(base) || !relative.endsWith('.bin')) throw Error('Invalid terrain path: ' + relative);
    const target = path.resolve(stage, relative);
    const inside = path.relative(stage, target);
    if (path.isAbsolute(inside) || inside.startsWith('..') || !fs.lstatSync(target).isFile() ||
        fs.realpathSync(target) !== target) throw Error('Terrain path escapes staging: ' + relative);
    return target;
  };
  const manifests = [];
  const originals = new Map();
  const contents = new Map();
  // Validate and hash every reference before changing the staged graph.
  for (const map of fs.readdirSync(path.join(stage, base), {withFileTypes: true})) {
    if (!map.isDirectory() || map.name === 'shared') continue;
    const file = path.join(stage, base, map.name, 'manifest.json');
    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const chunk of data.chunks) for (const lod of Object.values(chunk.lods)) {
      const original = lod.texture.replace(/^res:\/\//, '');
      if (!originals.has(original)) {
        const bytes = fs.readFileSync(resolve(original));
        const hash = crypto.createHash('sha256').update(bytes).digest('hex');
        const canonical = base + 'shared/' + hash + '.bin';
        originals.set(original, {canonical, bytes: bytes.length});
        if (!contents.has(canonical)) contents.set(canonical, original);
      }
      lod.texture = 'res://' + originals.get(original).canonical;
    }
    manifests.push({file, data});
  }
  const inputsFile = path.join(stage, 'release_inputs.json');
  const inputs = JSON.parse(fs.readFileSync(inputsFile, 'utf8'));
  fs.mkdirSync(path.join(stage, base, 'shared'), {recursive: true});
  for (const [canonical, original] of contents) {
    const target = path.join(stage, canonical);
    if (fs.existsSync(target)) throw Error('Terrain dedup requires a fresh stage: ' + target);
    try { fs.linkSync(resolve(original), target); }
    catch { fs.copyFileSync(resolve(original), target); }
  }
  for (const {file, data} of manifests) fs.writeFileSync(file, JSON.stringify(data));
  inputs.files = [...new Set(inputs.files.map(file => originals.get(file)?.canonical ?? file))].sort();
  const sourceBytes = [...originals.values()].reduce((sum, entry) => sum + entry.bytes, 0);
  const packedBytes = [...contents.values()].reduce((sum, file) => sum + originals.get(file).bytes, 0);
  inputs.terrainDedup = {files: originals.size, uniqueFiles: contents.size, sourceBytes, packedBytes, savedBytes: sourceBytes - packedBytes};
  fs.writeFileSync(inputsFile, JSON.stringify(inputs, null, 2) + '\n');
  for (const original of originals.keys()) fs.unlinkSync(resolve(original));
  return inputs.terrainDedup;
}
