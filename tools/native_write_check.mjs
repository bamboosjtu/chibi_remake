#!/usr/bin/env node
// P6 native write gate. sim_math.cpp mutates unit dictionaries directly, so the
// static GDScript write checker cannot see those writes. This gate parses the
// Keys struct and every `u[k.<alias>] = ...` assignment, then requires each
// resulting Godot field to exist in the unit ownership manifest and be listed in
// the reviewed native-write snapshot. New or stale native fields fail.

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const SOURCE = 'tools/native/sim_math/sim_math.cpp';
const REVIEW = 'tools/inputs/native_write_review.json';
const OWNERSHIP = 'tools/inputs/unit_schema_ownership.json';

export function scan(source) {
  const start = source.indexOf('struct Keys {');
  const end = source.indexOf('} k;', start);
  if (start < 0 || end < 0) throw new Error('sim_math.cpp: Keys struct not found');
  const keys = new Map();
  for (const [, alias, field] of source.slice(start, end).matchAll(/(\w+)\{"([^"]+)"\}/g)) keys.set(alias, field);
  const fields = new Set();
  const code = source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, ' ');
  for (const [, alias] of code.matchAll(/\bu\s*\[\s*k\s*\.\s*(\w+)\s*\]\s*(?:<<|>>|[+\-*/%&|^])?=(?!=)/g)) {
    if (!keys.has(alias)) throw new Error('sim_math.cpp: unknown key alias ' + alias);
    fields.add(keys.get(alias));
  }
  return [...fields].sort();
}

function main() {
  const args = process.argv.slice(2);
  const write = args.includes('--write');
  const source = fs.readFileSync(SOURCE, 'utf8');
  const ownership = JSON.parse(fs.readFileSync(OWNERSHIP, 'utf8')).fields;
  const fields = scan(source);
  const missing = fields.filter(field => !Object.hasOwn(ownership, field) ||
    typeof ownership[field]?.owner !== 'string' || !ownership[field].owner.trim());
  if (missing.length) throw Error('NATIVE WRITE: fields lack a unit owner: ' + missing.join(', '));
  const entries = fields.map((field) => ({field, owner: ownership[field].owner, writer: 'sim_math.cpp'}));
  if (write) {
    fs.writeFileSync(REVIEW, JSON.stringify({schemaVersion: 1, source: SOURCE, entries}, null, 2) + '\n');
    console.log(`NATIVE WRITE REVIEW WRITE ${entries.length} fields`);
    return;
  }
  const review = JSON.parse(fs.readFileSync(REVIEW, 'utf8'));
  if (review.schemaVersion !== 1 || review.source !== SOURCE || !Array.isArray(review.entries)) {
    throw Error('Invalid native write review header');
  }
  const reviewed = new Map();
  for (const record of review.entries) {
    if (typeof record?.field !== 'string' || !record.field) throw Error('Invalid native write review entry');
    if (reviewed.has(record.field)) throw Error('Duplicate native write review entry: ' + record.field);
    reviewed.set(record.field, record);
  }
  const errors = [];
  for (const expected of entries) {
    const record = reviewed.get(expected.field);
    if (!record) errors.push('NEW ' + expected.field);
    else if (record.owner !== expected.owner || record.writer !== expected.writer) {
      errors.push(`MISMATCH ${expected.field}: expected ${expected.owner} / ${expected.writer}, found ${record.owner} / ${record.writer}`);
    }
    reviewed.delete(expected.field);
  }
  for (const field of reviewed.keys()) errors.push('STALE ' + field);
  if (errors.length) throw Error('Native write review differs from source:\n' + errors.join('\n'));
  console.log(`NATIVE WRITE PASS ${fields.length} reviewed fields / owners / writers`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
