#!/usr/bin/env node
// Positive/negative fixtures for the unit and battle-state ownership gates.

import process from 'node:process';
import { validateUnit } from './unit_schema_ownership_check.mjs';
import { validateState } from './battle_state_ownership_check.mjs';

const schema = `extends RefCounted
const FIELDS := {
\t"hp": {"type": "int", "default": 1, "persist": true, "derived": false, "group": "record"},
\t"attack": {"type": "int", "default": 1, "persist": false, "derived": true, "group": "derived"},
}
`;

function unitOwnership(overrides = {}) {
  return {
    fieldCount: 2,
    fields: {
      hp: { owner: 'units', persist: true, derived: false, derived_by: null, lifecycle: 'unit_lifecycle', backing_store: 'unit.hp', readers: ['*'] },
      attack: { owner: 'combat', persist: false, derived: true, derived_by: 'combat', lifecycle: 'unit_combat', backing_store: 'unit.attack', readers: ['*'] },
      ...overrides,
    },
  };
}

const errors = [];
const check = (name, got, expected = 0) => { if (got !== expected) errors.push(`${name}: expected ${expected} errors, got ${got}`); };

check('unit valid', validateUnit(schema, unitOwnership()).errors.length);
check('unit missing field', validateUnit(schema, { fieldCount: 1, fields: { hp: unitOwnership().fields.hp } }).errors.length > 0 ? 1 : 0, 1);
check('unit wrong persist', validateUnit(schema, unitOwnership({ hp: { ...unitOwnership().fields.hp, persist: false } })).errors.length > 0 ? 1 : 0, 1);
check('unit invalid owner', validateUnit(schema, unitOwnership({ hp: { ...unitOwnership().fields.hp, owner: 'bogus' } })).errors.length > 0 ? 1 : 0, 1);
check('unit wrong derived', validateUnit(schema, unitOwnership({ attack: { ...unitOwnership().fields.attack, derived: false } })).errors.length > 0 ? 1 : 0, 1);

const state = `extends RefCounted
var hp := 1
var selected: Array:
\tget: return session.selected
\tset(value): session.selected = value
`;
const policy = `const INPUTS := ["hp"]
const RESET := []
const RESTORED := ["selected"]
const OBJECTS := []
const READ_ONLY := []
`;

function stateOwnership(overrides = {}) {
  return {
    fieldCount: 2,
    fields: {
      hp: { kind: 'storage', policy: 'INPUTS', owner: 'units', persist: true, backing_store: 'state.hp', readers: ['*'] },
      selected: { kind: 'proxy', policy: 'RESTORED', owner: 'commands', persist: false, backing_store: 'session.selected', readers: ['*'] },
      ...overrides,
    },
  };
}

check('state valid', validateState(state, policy, stateOwnership()).errors.length);
check('state missing field', validateState(state, policy, { fieldCount: 1, fields: { hp: stateOwnership().fields.hp } }).errors.length > 0 ? 1 : 0, 1);
check('state proxy backing', validateState(state, policy, stateOwnership({ selected: { ...stateOwnership().fields.selected, backing_store: 'session.other' } })).errors.length > 0 ? 1 : 0, 1);
check('state auto_control owner', validateState(
  'extends RefCounted\nvar auto_control := false\nvar hp := 1\nvar selected: Array:\n\tget: return session.selected\n\tset(value): session.selected = value\n',
  'const INPUTS := ["auto_control","hp"]\nconst RESET := []\nconst RESTORED := ["selected"]\nconst OBJECTS := []\nconst READ_ONLY := []\n',
  { fieldCount: 3, fields: { auto_control: { kind: 'storage', policy: 'INPUTS', owner: 'commands', persist: true, backing_store: 'state.auto_control', readers: ['*'] }, ...stateOwnership().fields } },
).errors.length > 0 ? 1 : 0, 1);

if (errors.length) {
  console.error(`OWNERSHIP TESTS FAIL: ${errors.length}`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('OWNERSHIP TESTS PASS: 8 cases');
