import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {dedupeTerrain} from './lib/terrain_dedup.mjs';

fs.mkdirSync('_work', {recursive: true});
const root = fs.mkdtempSync(path.resolve('_work/terrain-dedup-'));
const prefix = 'art/full/terrain_chunks/';
const make = (name, values) => {
  const directory = path.join(root, name);
  const chunk = prefix + 'chibil1/';
  fs.mkdirSync(path.join(directory, chunk), {recursive: true});
  const files = values.map((bytes, i) => {
    const file = chunk + i + '.bin';
    fs.writeFileSync(path.join(directory, file), Buffer.from(bytes));
    return file;
  });
  fs.writeFileSync(path.join(directory, chunk, 'manifest.json'), JSON.stringify({chunks: files.map(texture => ({lods: {4: {texture: 'res://' + texture}}}))}));
  fs.writeFileSync(path.join(directory, 'release_inputs.json'), JSON.stringify({files, sourceFiles: ['source.jpg']}));
  return directory;
};
const stage = make('valid', [[1, 2, 3], [1, 2, 3], [4, 5]]);
const result = dedupeTerrain(stage);
assert.deepEqual(result, {files: 3, uniqueFiles: 2, sourceBytes: 8, packedBytes: 5, savedBytes: 3});
const manifest = JSON.parse(fs.readFileSync(path.join(stage, prefix, 'chibil1/manifest.json')));
assert.equal(manifest.chunks[0].lods[4].texture, manifest.chunks[1].lods[4].texture);
for (const [i, bytes] of [[1, 2, 3], [1, 2, 3], [4, 5]].entries()) {
  assert.deepEqual([...fs.readFileSync(path.join(stage, manifest.chunks[i].lods[4].texture.slice(6)))], bytes);
}
const inputs = JSON.parse(fs.readFileSync(path.join(stage, 'release_inputs.json')));
assert.equal(inputs.files.length, 2);
assert.deepEqual(inputs.sourceFiles, ['source.jpg']);
assert(!fs.existsSync(path.join(stage, prefix, 'chibil1/0.bin')));
const invalid = make('invalid', [[1]]);
const file = path.join(invalid, prefix, 'chibil1/manifest.json');
const bad = JSON.parse(fs.readFileSync(file));
bad.chunks[0].lods[4].texture = 'res://' + prefix + '../../../escape.bin';
fs.writeFileSync(file, JSON.stringify(bad));
const before = fs.readFileSync(file, 'utf8');
assert.throws(() => dedupeTerrain(invalid));
assert.equal(fs.readFileSync(file, 'utf8'), before);
assert(fs.existsSync(path.join(invalid, prefix, 'chibil1/0.bin')));
console.log('TERRAIN DEDUP PASS identical transport / distinct content / reference graph / source retention / unsafe path rejected before mutation');
