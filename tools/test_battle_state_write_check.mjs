import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { evaluate, scanSource } from './battle_state_write_check.mjs';

const states = { gold: { owner: 'economy' }, selected: { owner: 'commands', backing_store: 'session.selected' } };
const units = { path: { owner: 'movement' }, state: { owner: 'units', transitions: ['commands'] } };
const source = 'func probe():\n' +
  '\tif battle.gold == 10: pass\n' +
  '\t# battle.gold = 0\n' +
  '\tvar description = "battle.gold = 0"\n' +
  '\tbattle.selected.append(unit)\n' +
  '\tbattle.session.selected.clear()\n' +
  '\tvar model = battle\n' +
  '\tmodel.gold = 1\n' +
  '\tvar selection = model.selected\n' +
  '\tselection.erase(unit)\n' +
  '\tbattle.set("gold", 2)\n' +
  '\tbattle.set(key, value)\n' +
  '\tbattle[key] = value\n' +
  '\tunit.path[0] = point\n' +
  '\tstate.units[0].path.append(point)\n' +
  '\tu.state = "attack"\n' +
  '\tu["state"] = "idle"\n';
assert.deepEqual(scanSource('app/probe.gd', source, states, units).map(write => [write.kind, write.field, write.operation]), [
  ['state', 'selected', 'append'],
  ['state', 'selected', 'clear'],
  ['state', 'gold', 'assign'],
  ['state', 'selected', 'erase'],
  ['state', 'gold', 'set'],
  ['state', '<dynamic>', 'set'],
  ['state', '<dynamic>', 'assign'],
  ['unit', 'path', 'assign'],
  ['unit', 'path', 'append'],
  ['unit', 'state', 'assign'],
  ['unit', 'state', 'assign'],
]);

const parent = path.resolve('_work');
fs.mkdirSync(parent, { recursive: true });
const root = fs.mkdtempSync(path.join(parent, 'field-write-'));
try {
  const write = (name, source) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, source);
  };
  write('app/probe.gd', 'func probe():\n\tbattle.gold = 1\n');
  const check = (entries = []) => evaluate(root, { fields: states }, { entries }, { fields: units });
  const [previous] = check().unbaselined;
  assert.equal(previous.field, 'gold');
  assert.deepEqual(check([previous]).unbaselined, []);
  write('app/probe.gd', 'func probe():\n\tbattle.gold = 1\n\tbattle.gold = 1\n');
  assert.equal(check([previous]).unbaselined.length, 1);
  write('app/probe.gd', 'func probe():\n\tpass\n');
  assert.deepEqual(check([previous]).stale, [previous]);
  write('simulation/world/probe.gd', 'func probe():\n\tbattle.gold = 1\n');
  assert.equal(check().unbaselined.length, 1);
  write('simulation/movement/probe.gd', 'func probe(unit):\n\tunit.path = []\n');
  assert.equal(check().unbaselined.length, 1);
  // unit.state is owned by units: an undeclared domain must still fail, a
  // declared transition domain must pass.
  write('simulation/world/probe.gd', 'func probe():\n\tpass\n');
  write('simulation/movement/probe.gd', 'func probe(unit):\n\tunit.state = "idle"\n');
  assert.equal(check().unbaselined.length, 1);
  write('simulation/movement/probe.gd', 'func probe(unit):\n\tpass\n');
  write('simulation/commands/probe.gd', 'func probe(unit):\n\tunit["state"] = "idle"\n');
  assert.deepEqual(check().unbaselined, []);
} finally {
  assert.equal(path.dirname(fs.realpathSync(root)), fs.realpathSync(parent));
  fs.rmSync(root, { recursive: true, force: true });
}
console.log('FIELD WRITE NEGATIVE PASS aliases, containers, unit fields, unit.state detection, transitions, and one allowance per site');
