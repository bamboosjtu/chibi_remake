#!/usr/bin/env node
/**
 * scenario — parse Set\BATTLE.EXP (the 34-mission campaign table).
 *
 * Structure recovered from the loader CB.EXE 0x0042b790 (see docs/11-campaign.md).
 * It reads the mission count, skips `param_2` missions, then parses the target one:
 *
 *   count                                   "%d"
 *   for each mission:
 *     id, participantCount, flag            "%d,%d,%d"
 *     mapName, aviName                      "%s %s"
 *     for each participant:
 *       owner                               "%d,"
 *       init[3]                             "%d,%d,%d"
 *       resources[4]                        "%d, %d, %d, %d"   -> DAT_004b8d08/8cfc/8d00/8d04
 *       n = ...                             "%d, "
 *       roster[n]                           n x "%d,"           -> officer indices
 *       ranks[n]                            n x "%d,"           -> officer tier/rank
 *
 * The loader sets DAT_004b8cac (the human player's owner) from participant
 * index (DAT_004b8b40 - 1); every other participant is flagged enemy (2).
 *
 * Usage: node scenario.mjs [--set iso/SET] [--json out.json]
 */
import fs from 'node:fs';
import { readExpText } from './exptable.mjs';

export function parseBattleExp(file) {
  const text = readExpText(file);
  // whitespace-insensitive token walk, preserving the "a, b, c" grouping by commas
  let i = 0;
  const num = () => {
    const m = /^\s*,?\s*(-?\d+)/.exec(text.slice(i));
    if (!m) throw new Error(`expected a number at ${i}: ${JSON.stringify(text.slice(i, i + 40))}`);
    i += m[0].length;
    return Number(m[1]);
  };
  const word = () => {
    const m = /^\s*([^\s,]+)/.exec(text.slice(i));
    if (!m) throw new Error(`expected a token at ${i}`);
    i += m[0].length;
    return m[1];
  };
  const skipComma = () => { const m = /^\s*,\s*/.exec(text.slice(i)); if (m) i += m[0].length; };

  const count = num();
  const missions = [];
  for (let k = 0; k < count; k++) {
    const id = num();
    const participants = num();
    const flag = num();
    const mapName = word();
    const aviName = word();
    const sides = [];
    for (let p = 0; p < participants; p++) {
      const owner = num();
      const init = [num(), num(), num()];
      const resources = [num(), num(), num(), num()];
      const n = num();
      const roster = [];
      for (let j = 0; j < n; j++) roster.push(num());
      const ranks = [];
      for (let j = 0; j < n; j++) ranks.push(num());
      sides.push({ owner, init, resources, roster, ranks });
    }
    missions.push({ id, flag, mapName, aviName, sides });
  }
  return { count, missions, leftover: text.slice(i).trim().length, rest: text.slice(i).trim().slice(0, 120) };
}

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) {
  const argv = process.argv.slice(2);
  let set = 'iso/SET', json = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--set') set = argv[++i];
    else if (argv[i] === '--json') json = argv[++i];
  }
  const d = parseBattleExp(`${set}/BATTLE.EXP`);
  console.log(`BATTLE.EXP: ${d.count} missions, leftover chars = ${d.leftover}`);
  if (d.leftover) console.log('  leftover head:', JSON.stringify(d.rest));
  const owners = new Set();
  for (const m of d.missions) for (const s of m.sides) owners.add(s.owner);
  console.log('  owners used:', [...owners].sort().join(','));
  console.log('\n  id  map            avi           ' + d.missions[0].sides.map((_, k) => `side${k}(owner,res,roster)`).join('  '));
  for (const m of d.missions) {
    const parts = m.sides.map((s) => `o${s.owner} r[${s.resources.join('/')}] n${s.roster.length}`);
    console.log(`  ${String(m.id).padStart(2)}  ${m.mapName.padEnd(14)} ${m.aviName.padEnd(13)} ${parts.join('  ')}`);
  }
  if (json) {
    fs.writeFileSync(json, JSON.stringify({ kind: 'campaign', schemaVersion: 1, missions: d.missions }, null, 0));
    console.log(`\nwrote ${json}`);
  }
}
