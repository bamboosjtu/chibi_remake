#!/usr/bin/env node
// 高清绘画母版/装配图集的哈希清单（P0-5：11.8 GB 运行素材不入 Git，但必须可校验、可备份）。
//
//   node tools/art_manifest.mjs --write   生成 tools/inputs/art.sha256（sha256 + bytes + path）
//   node tools/art_manifest.mjs --check   只校验存在性与文件大小（快）
//   node tools/art_manifest.mjs --check --hash  全量重算 SHA-256（约 11.8 GB，慢但最强）
//
// 清单只覆盖运行时母版，不含 .import/.uid 这类 Godot 源元数据。

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = process.cwd();
const BASE = 'godot/chibi_remake/art/full';
const MANIFEST = 'tools/inputs/art.sha256';
const argv = process.argv.slice(2);
const mode = argv.includes('--write') ? 'write' : argv.includes('--check') ? 'check' : '';
const wantHash = argv.includes('--hash');
if (!mode) {
  console.error('用法: node tools/art_manifest.mjs --write | --check [--hash]');
  process.exit(2);
}

function walk(dir, prefix, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const rel = prefix ? prefix + '/' + entry.name : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, rel, out);
    else if (!entry.name.endsWith('.import') && !entry.name.endsWith('.uid')) out.push(rel);
  }
}

const files = [];
walk(path.join(ROOT, BASE), '', files);

if (mode === 'write') {
  const lines = [];
  let bytes = 0;
  let done = 0;
  for (const rel of files) {
    const full = path.join(ROOT, BASE, rel);
    const buf = fs.readFileSync(full);
    const hash = crypto.createHash('sha256').update(buf).digest('hex');
    lines.push(hash + '\t' + buf.length + '\t' + rel);
    bytes += buf.length;
    done++;
    if (done % 5000 === 0) console.error('hashed ' + done + '/' + files.length);
  }
  fs.mkdirSync(path.dirname(path.join(ROOT, MANIFEST)), { recursive: true });
  fs.writeFileSync(path.join(ROOT, MANIFEST), lines.join('\n') + '\n');
  console.log('ART MANIFEST WRITE: ' + files.length + ' files, ' + (bytes / 2 ** 30).toFixed(2) + ' GiB -> ' + MANIFEST);
  process.exit(0);
}

if (!fs.existsSync(path.join(ROOT, MANIFEST))) {
  console.error('ART MANIFEST MISSING: ' + MANIFEST + '（先运行 --write 或从备份恢复）');
  process.exit(1);
}
const rows = fs.readFileSync(path.join(ROOT, MANIFEST), 'utf8').split(/\r?\n/).filter(Boolean).map((line) => {
  const [hash, size, ...rest] = line.split('\t');
  return { hash, size: Number(size), rel: rest.join('\t') };
});
let missing = 0, bad = 0;
for (const row of rows) {
  const full = path.join(ROOT, BASE, row.rel);
  if (!fs.existsSync(full)) { missing++; console.error('MISSING ' + row.rel); continue; }
  const st = fs.statSync(full);
  if (st.size !== row.size) { bad++; console.error('SIZE MISMATCH ' + row.rel + ' ' + st.size + ' != ' + row.size); continue; }
  if (wantHash) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex');
    if (actual !== row.hash) { bad++; console.error('HASH MISMATCH ' + row.rel); }
  }
}
const listed = new Set(rows.map((r) => r.rel));
const extra = files.filter((f) => !listed.has(f));
console.log('ART MANIFEST CHECK: listed=' + rows.length + ' present=' + files.length + ' missing=' + missing + ' bad=' + bad + ' extra=' + extra.length + (wantHash ? ' (sha256)' : ' (size only)'));
if (extra.length) extra.slice(0, 20).forEach((f) => console.error('EXTRA ' + f));
process.exit(missing || bad || extra.length ? 1 : 0);
