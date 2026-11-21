#!/usr/bin/env node
// P6 native write gate. sim_math.cpp mutates unit dictionaries directly, so the
// static GDScript write checker cannot see those writes. This gate parses the
// Keys struct and every `u[k.<alias>] = ...` assignment, then requires each
// resulting Godot field to exist in the unit ownership manifest and be listed in
// the reviewed native-write snapshot. New or stale native fields fail.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const SOURCE = 'tools/native/sim_math/sim_math.cpp';
const REVIEW = 'tools/inputs/native_write_review.json';
const OWNERSHIP = 'tools/inputs/unit_schema_ownership.json';

export function scan(source) {
  const start = source.indexOf('struct Keys {');
  const end = source.indexOf('} k;', start);
  if (start < 0 || end < 0) throw new Error('sim_math.cpp: Keys struct not found');
  const keys = {};
  for (const match of source.slice(start, end).matchAll(/(\w+)\{"([^"]+)"\}/g)) keys[match[1]] = match[2];
  const fields = new Set();
  for (const match of source.matchAll(/u\[k\.(\w+)\]\s*(?:\+|-|\*|\/|%|&|\||\^|<<|>>)?=/g)) {
    if (!keys[match[1]]) throw new Error('sim_math.cpp: unknown key alias ' + match[1]);
    fields.add(keys[match[1]]);
  }
  return [...fields].sort();
}

function main() {
  const args = process.argv.slice(2);
  const write = args.includes('--write');
  const source = fs.readFileSync(SOURCE, 'utf8');
  const ownership = JSON.parse(fs.readFileSync(OWNERSHIP, 'utf8')).fields;
  const fields = scan(source);
  const missing = fields.filter((field) => !ownership[field]);
  if (missing.length) {
    console.error('NATIVE WRITE: fields absent from unit ownership: ' + missing.join(', '));
    process.exit(1);
  }
  const entries = fields.map((field) => ({field, owner: ownership[field].owner, writer: 'sim_math.cpp'}));
  if (write) {
    fs.writeFileSync(REVIEW, JSON.stringify({schemaVersion: 1, source: SOURCE, entries}, null, 2) + '\n');
    console.log(`NATIVE WRITE REVIEW WRITE ${entries.length} fields`);
    return;
  }
  const review = JSON.parse(fs.readFileSync(REVIEW, 'utf8')).entries || [];
  const reviewed = new Set(review.map((entry) => entry.field));
  const current = new Set(fields);
  const added = fields.filter((field) => !reviewed.has(field));
  const stale = [...reviewed].filter((field) => !current.has(field));
  console.log(`NATIVE WRITE: ${fields.length} fields, ${added.length} new, ${stale.length} stale`);
  for (const field of added) console.error(`  NEW ${field}`);
  for (const field of stale) console.error(`  STALE ${field}`);
  if (added.length || stale.length) process.exit(1);
  console.log('NATIVE WRITE PASS');
}

if (process.argv[1]?.endsWith('native_write_check.mjs')) main();
