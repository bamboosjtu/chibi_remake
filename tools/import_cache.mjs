import fs from 'node:fs';
import path from 'node:path';
import {createHash, randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';

// This is the index format of the pinned Godot engine. Seed only independent
// built-in imports. Godot rescans everything else and revalidates seeded rows.
const indexName = 'filesystem_cache10';
const destinationPrefix = 'res://.godot/imported/';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const md5 = bytes => createHash('md5').update(bytes).digest('hex');
const read = file => {
  try { return fs.readFileSync(file); }
  catch (error) { if (error.code !== 'ENOENT') throw error; return null; }
};
const readJson = file => {
  try { return JSON.parse(read(file)); } catch (error) { if (!(error instanceof SyntaxError)) throw error; return null; }
};
const safeAsset = /^[-\w./]+\.(png|ogg|wav|otf|ttf)$/i;
const safeBlob = /^[a-f0-9]{64}$/;
const outputName = /^[-\w.]+-[a-f0-9]{32}\.(ctex|oggvorbisstr|sample|fontdata)$/;
const importers = {
  png: ['texture', 'ctex'], ogg: ['oggvorbisstr', 'oggvorbisstr'],
  wav: ['wav', 'sample'], otf: ['font_data_dynamic', 'fontdata'], ttf: ['font_data_dynamic', 'fontdata'],
};

function contextFiles(directory, prefix) {
  const names = [];
  if (!fs.existsSync(path.join(directory, prefix))) return names;
  for (const entry of fs.readdirSync(path.join(directory, prefix), {withFileTypes: true})) {
    const name = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) names.push(...contextFiles(directory, name));
    else if (entry.isFile()) names.push(name);
  }
  return names;
}

function loadInputs(stage, engine) {
  const manifest = JSON.parse(fs.readFileSync(path.join(stage, 'release_inputs.json'), 'utf8'));
  const context = createHash('sha256').update('chibi-import-cache-v1\0').update(fs.readFileSync(engine));
  for (const file of ['project.godot', 'export_presets.cfg', ...contextFiles(stage, 'addons')].sort()) {
    context.update(JSON.stringify([file, sha256(fs.readFileSync(path.join(stage, file)))]));
  }
  const inputs = {};
  for (const file of manifest.sourceFiles) {
    if (!safeAsset.test(file) || file.startsWith('/') || file.split('/').includes('..') || file.startsWith('addons/')) continue;
    const asset = path.join(stage, file);
    const source = fs.readFileSync(asset);
    const sidecar = read(asset + '.import');
    const uid = read(asset + '.uid');
    inputs[file] = {
      identity: sha256(JSON.stringify([sha256(source), sidecar && sha256(sidecar), uid && sha256(uid)])),
      sourceMd5: md5(source),
    };
  }
  return {context: context.digest('hex'), inputs};
}

function importRecord(file, row, metadata, input) {
  const [importer, extension] = importers[path.extname(file).slice(1).toLowerCase()];
  if (typeof row !== 'string' || typeof metadata !== 'string' || /[\r\n]/.test(row)) return null;
  const parts = row.split('::');
  const fields = parts[7]?.split('<>');
  if (parts.length !== 9 || parts[0] !== path.posix.basename(file) || parts[5] !== '1' ||
      parts[6] || parts[8] || fields?.length !== 7 || fields[5] !== md5(metadata)) return null;
  const dest = fields[6];
  const name = dest.slice(destinationPrefix.length);
  if (!dest.startsWith(destinationPrefix) || !outputName.test(name) || !name.endsWith('.' + extension) ||
      !metadata.includes('importer="' + importer + '"') || !metadata.includes('source_file="res://' + file + '"') ||
      !metadata.includes('dest_files=["' + dest + '"]')) return null;
  // Distinct virtual paths must never collide, even when their input bytes match.
  const stem = path.posix.basename(file) + '-' + md5('res://' + file);
  if (name !== stem + '.' + extension) return null;
  parts[3] = '0';
  parts[4] = '0';
  return {name, md5Name: stem + '.md5', row: parts.join('::'), sourceMd5: input.sourceMd5};
}

function validImport(sourceMd5, data, checksums) {
  return checksums.includes('source_md5="' + sourceMd5 + '"') &&
    checksums.includes('dest_md5="' + md5(data) + '"');
}

export function prepareImportCache(stage, engine, cache) {
  const state = loadInputs(stage, engine);
  const editor = path.join(stage, '.godot/editor');
  const imported = path.join(stage, '.godot/imported');
  fs.mkdirSync(editor, {recursive: true});
  fs.writeFileSync(path.join(stage, '.godot/chibi-import-inputs.json'), JSON.stringify(state));
  const previous = readJson(path.join(cache, state.context + '.json'));
  if (!previous || !/^[a-f0-9]{32}$/.test(previous.settings)) return 0;
  let reused = 0;
  const rows = [previous.settings];
  for (const [file, input] of Object.entries(state.inputs)) {
    const record = previous.assets?.[file];
    if (record?.identity !== input.identity || !safeBlob.test(record.blob) ||
        typeof record.checksums !== 'string') continue;
    const seeded = importRecord(file, record.row, record.metadata, input);
    if (!seeded) continue;
    const bytes = read(path.join(cache, 'blobs', record.blob));
    if (!bytes || sha256(bytes) !== record.blob || !validImport(seeded.sourceMd5, bytes, record.checksums)) continue;
    fs.mkdirSync(imported, {recursive: true});
    fs.writeFileSync(path.join(imported, seeded.name), bytes);
    fs.writeFileSync(path.join(imported, seeded.md5Name), record.checksums);
    fs.writeFileSync(path.join(stage, file + '.import'), record.metadata);
    const directory = path.posix.dirname(file);
    // Each directory header may only appear once in Godot's index.
    rows.push([directory, seeded.row]);
    reused++;
  }
  if (reused) {
    const groups = Map.groupBy(rows.slice(1), ([directory]) => directory);
    const lines = [rows[0]];
    for (const [directory, entries] of groups) {
      lines.push('::res://' + (directory === '.' ? '' : directory + '/') + '::0', ...entries.map(([, row]) => row));
    }
    fs.writeFileSync(path.join(editor, indexName), lines.join('\n') + '\n');
  }
  return reused;
}

export function storeImportCache(stage, cache) {
  const state = readJson(path.join(stage, '.godot/chibi-import-inputs.json'));
  const index = read(path.join(stage, '.godot/editor', indexName));
  if (!state || !index) return 0;
  const [settings, ...lines] = index.toString('utf8').split(/\r?\n/);
  if (!/^[a-f0-9]{32}$/.test(settings)) return 0;
  const assets = {};
  let directory = '';
  fs.mkdirSync(path.join(cache, 'blobs'), {recursive: true});
  for (const row of lines) {
    if (row.startsWith('::res://')) { directory = row.split('::')[1].slice(6); continue; }
    const file = directory + row.split('::', 1)[0];
    if (!Object.hasOwn(state.inputs, file)) continue;
    const input = state.inputs[file];
    const metadata = read(path.join(stage, file + '.import'))?.toString('utf8');
    const record = importRecord(file, row, metadata, input);
    if (!record) continue;
    const bytes = read(path.join(stage, '.godot/imported', record.name));
    const checksums = read(path.join(stage, '.godot/imported', record.md5Name))?.toString('utf8');
    if (!bytes || !checksums || !validImport(input.sourceMd5, bytes, checksums)) continue;
    const blob = sha256(bytes);
    const destination = path.join(cache, 'blobs', blob);
    const existing = read(destination);
    if (!existing || sha256(existing) !== blob) atomicWrite(destination, bytes);
    assets[file] = {identity: input.identity, row, metadata, checksums, blob};
  }
  atomicWrite(path.join(cache, state.context + '.json'), JSON.stringify({settings, assets}));
  return Object.keys(assets).length;
}

function atomicWrite(file, bytes) {
  const temporary = file + '.' + randomUUID() + '.tmp';
  try {
    fs.writeFileSync(temporary, bytes, {flag: 'wx'});
    fs.renameSync(temporary, file);
  } finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, stage, engine, cache] = process.argv.slice(2);
  if (!stage || !engine || !cache || !['prepare', 'store'].includes(mode)) throw Error('Usage: import_cache.mjs prepare|store stage engine cache');
  const count = mode === 'prepare' ? prepareImportCache(stage, engine, cache) : storeImportCache(stage, cache);
  console.log('GODOT IMPORT CACHE ' + mode + ': ' + count + ' resources');
}
