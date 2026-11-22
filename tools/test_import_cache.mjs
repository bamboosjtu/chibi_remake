import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {crc32, deflateSync} from 'node:zlib';
import {prepareImportCache, storeImportCache} from './import_cache.mjs';
import {runGodot} from './lib/godot_process.mjs';

const engineFlag = process.argv.indexOf('--engine');
assert(engineFlag > 0 && process.argv[engineFlag + 1], 'Pass the reviewed engine with --engine');
const engine = path.resolve(process.argv[engineFlag + 1]);
const parent = path.resolve('_work/import-cache-tests');
fs.mkdirSync(parent, {recursive: true});
const fixture = fs.mkdtempSync(path.join(parent, 'case-'));
const cache = path.join(fixture, 'cache');
const project = 'config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';

function pixel(red, green, blue) {
  const chunk = (tag, data) => {
    const body = Buffer.concat([Buffer.from(tag), data]);
    const size = Buffer.alloc(4), checksum = Buffer.alloc(4);
    size.writeUInt32BE(data.length); checksum.writeUInt32BE(crc32(body));
    return Buffer.concat([size, body, checksum]);
  };
  const header = Buffer.from([0,0,0,1,0,0,0,1,8,2,0,0,0]);
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', header),
    chunk('IDAT', deflateSync(Buffer.from([0, red, green, blue]))), chunk('IEND', Buffer.alloc(0))]);
}

function makeStage(name, newColor = false) {
  const stage = path.join(fixture, name);
  fs.mkdirSync(path.join(stage, 'art'), {recursive: true});
  fs.writeFileSync(path.join(stage, 'project.godot'), project);
  fs.writeFileSync(path.join(stage, 'export_presets.cfg'), '');
  fs.writeFileSync(path.join(stage, 'release_inputs.json'), JSON.stringify({sourceFiles: ['art/first.png', 'art/second.png']}));
  fs.writeFileSync(path.join(stage, 'art/first.png'), pixel(255, 0, 0));
  fs.writeFileSync(path.join(stage, 'art/second.png'), newColor ? pixel(0, 0, 255) : pixel(0, 255, 0));
  return stage;
}

async function importStage(stage) {
  const result = await runGodot({engine, directory: fixture, name: path.basename(stage), timeout: 60,
    args: ['--headless', '--path', stage, '--import']});
  assert(result.ok, result.output);
  return result.output;
}

const cold = makeStage('cold');
assert.equal(prepareImportCache(cold, engine, cache), 0);
await importStage(cold);
assert.equal(storeImportCache(cold, cache), 2, 'Cold import must cache both verified outputs');
const warm = makeStage('warm', true);
assert.equal(prepareImportCache(warm, engine, cache), 1, 'A changed texture must miss while its unchanged neighbor hits');
assert(fs.existsSync(path.join(warm, 'art/first.png.import')));
assert(!fs.existsSync(path.join(warm, 'art/second.png.import')));
const warmLog = await importStage(warm);
assert.match(warmLog, /reimport[^\r\n]*second\.png/, 'Godot must import changed bytes');
assert.doesNotMatch(warmLog, /reimport[^\r\n]*first\.png/, 'Godot must reuse the unchanged import');
assert.equal(storeImportCache(warm, cache), 2);

const manifest = fs.readdirSync(cache).find(file => file.endsWith('.json'));
const snapshot = JSON.parse(fs.readFileSync(path.join(cache, manifest), 'utf8'));
fs.writeFileSync(path.join(cache, 'blobs', snapshot.assets['art/first.png'].blob), 'damaged import');
const damaged = makeStage('damaged', true);
assert.equal(prepareImportCache(damaged, engine, cache), 1, 'Damaged compiled output must miss');
const repairedLog = await importStage(damaged);
assert.match(repairedLog, /reimport[^\r\n]*first\.png/);
assert.equal(storeImportCache(damaged, cache), 2);
const settingsChanged = makeStage('settings-changed', true);
fs.appendFileSync(path.join(settingsChanged, 'project.godot'), '\n[application]\nconfig/name="changed settings"\n');
assert.equal(prepareImportCache(settingsChanged, engine, cache), 0);
console.log('GODOT IMPORT CACHE PASS cold / selective reuse / changed asset / corrupt output / changed project settings');
