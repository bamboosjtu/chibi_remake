#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const STATE_RECEIVERS = new Set(['battle', 'state', '_state', 'target_state']);
const UNIT_RECEIVERS = new Set('u unit nu gate commander worker member leader ship bship target other attacker victim enemy passenger carrier rt bt'.split(' '));
const MUTATORS = new Set('append append_array assign clear erase fill insert merge pop_at pop_back pop_front push_back push_front remove_at resize reverse shuffle sort sort_custom'.split(' '));
const RESTORER = 'app/saves/snapshot_restorer.gd';
const SESSION = 'simulation/state/battle_state.gd';
const STEP = /[ \t]*(?:\.[ \t]*(?<member>[A-Za-z_]\w*)(?:[ \t]*\([ \t]*(?<getKey>["'][A-Za-z_]\w*["'])[ \t]*\))?|\[[ \t]*(?<index>[^\]\r\n]+)\])/gy;
const WRITE = /^[ \t]*(?:[+*/%&|^-]=|<<=|>>=|=(?!=))/;
const NON_CODE = /("""(?:\\[\s\S]|(?!""")[^\\])*"""|'''(?:\\[\s\S]|(?!''')[^\\])*'''|"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*')|#[^\r\n]*/g;
const blank = text => text.replace(/[^\r\n]/g, ' ');
const keyOf = value => /^(['"])([A-Za-z_]\w*)\1$/.exec(value?.trim() ?? '')?.[2];

function chain(line, index) {
  const name = /^[A-Za-z_]\w*/.exec(line.slice(index))?.[0];
  if (!name) return null;
  let end = index + name.length;
  const segments = [name];
  const starts = [index];
  while (true) {
    STEP.lastIndex = end;
    const match = STEP.exec(line);
    if (!match || (match.groups.getKey && match.groups.member !== 'get')) break;
    starts.push(end);
    end = STEP.lastIndex;
    const { member, getKey, index: subscript } = match.groups;
    segments.push(member ? (getKey ? keyOf(getKey) : member) : (keyOf(subscript) ?? '[]'));
  }
  return { segments, end, starts };
}

function ownerField(segments, aliases, stateFields, unitFields) {
  const [root, ...parts] = segments;
  const alias = aliases.get(root);
  if (alias?.kind === 'state-field' || alias?.kind === 'unit-field') return { ...alias, accessLength: parts.length };
  const nestedState = parts[0] === 'state';
  if (nestedState) parts.shift();
  if (nestedState || alias?.kind === 'state' || STATE_RECEIVERS.has(root) || root === 'session') {
    if (nestedState && parts.length === 0) return { kind: 'state', accessLength: 0 };
    if (parts[0] === 'session' || root === 'session' || alias?.kind === 'session') {
      if (parts[0] === 'session') parts.shift();
      if (!parts.length) return { kind: 'session', accessLength: 0 };
      if (stateFields[parts[0]]?.backing_store !== 'session.' + parts[0]) return null;
    }
    if (!parts.length) return { kind: 'state', accessLength: 0 };
    if (parts[0] === 'units' && parts[1] === '[]') {
      if (parts.length === 2) return { kind: 'unit', accessLength: 0 };
      if (unitFields[parts[2]]) return { kind: 'unit-field', field: parts[2], accessLength: parts.length - 3 };
      return null;
    }
    if (parts[0] === '[]') return { kind: 'state-field', field: '<dynamic>', accessLength: parts.length - 1 };
    if (stateFields[parts[0]]) return { kind: 'state-field', field: parts[0], accessLength: parts.length - 1 };
  }
  if (alias?.kind === 'session') {
    if (!parts.length) return alias;
    if (stateFields[parts[0]]?.backing_store === 'session.' + parts[0]) return { kind: 'state-field', field: parts[0], accessLength: parts.length - 1 };
  }
  if (alias?.kind === 'unit' || UNIT_RECEIVERS.has(root)) {
    if (!parts.length) return { kind: 'unit', accessLength: 0 };
    if (parts[0] === '[]') return { kind: 'unit-field', field: '<dynamic>', accessLength: parts.length - 1 };
    if (unitFields[parts[0]]) return { kind: 'unit-field', field: parts[0], accessLength: parts.length - 1 };
  }
  return null;
}

export function scanSource(file, source, stateFields, unitFields) {
  const writes = [];
  const code = source.replace(NON_CODE, (value, literal) => literal ?? blank(value));
  const masked = code.replace(NON_CODE, blank);
  const lines = code.split('\n');
  const masks = masked.split('\n');
  const aliases = new Map();
  let scope = '<script>';
  let indent = 0;
  for (const [number, line] of lines.entries()) {
    const visible = masks[number];
    const definition = /^(?:static )?func (\w+)\(/.exec(visible);
    if (definition) {
      scope = definition[1];
      aliases.clear();
      indent = 0;
    }
    const depth = /^[ \t]*/.exec(visible)[0].length;
    if (visible.trim() && depth < indent) {
      for (const [name, kind] of aliases) if (kind.depth > depth) aliases.delete(name);
    }
    if (visible.trim()) indent = depth;
    for (const root of visible.matchAll(/(?<![.\w])\b[A-Za-z_]\w*/g)) {
      const access = chain(line, root.index);
      if (!access || access.segments.length < 2) continue;
      const last = access.segments.at(-1);
      const after = line.slice(access.end);
      let field = ownerField(access.segments, aliases, stateFields, unitFields);
      let operation = WRITE.test(after) ? 'assign' : null;
      if (operation && field?.kind === 'unit' && last === '[]') field = { kind: 'state-field', field: 'units' };
      if (/^[ \t]*\(/.test(after) && (MUTATORS.has(last) || last === 'set')) {
        const receiver = ownerField(access.segments.slice(0, -1), aliases, stateFields, unitFields);
        if (!receiver) continue;
        field = receiver;
        operation = last;
        if (last === 'set' && ['state', 'session', 'unit'].includes(receiver.kind)) {
          const key = keyOf(/^[ \t]*\([ \t]*([^,]+)/.exec(after)?.[1]);
          if (key && !(receiver.kind === 'unit' ? unitFields[key] : stateFields[key])) continue;
          if (key && receiver.kind === 'session' && stateFields[key]?.backing_store !== 'session.' + key) continue;
          field = { kind: receiver.kind === 'unit' ? 'unit-field' : 'state-field', field: key ?? '<dynamic>', accessLength: 0 };
        } else if (receiver.kind === 'unit' && MUTATORS.has(last)) {
          const key = last === 'erase' ? keyOf(/^[ \t]*\([ \t]*([^,)]+)/.exec(after)?.[1]) : null;
          if (key && !unitFields[key]) continue;
          field = { kind: 'unit-field', field: key ?? '<dynamic>' };
        }
      }
      if (!operation || !field?.field) continue;
      const kind = field.kind === 'unit-field' ? 'unit' : 'state';
      const schema = kind === 'unit' ? unitFields : stateFields;
      const semicolon = visible.indexOf(';', root.index);
      const site = line.slice(root.index, semicolon === -1 ? line.length : semicolon).trim();
      writes.push({ file, scope, kind, field: field.field, line: number + 1, owner: schema[field.field]?.owner ?? null, operation, site });
    }
    // A simple assignment can bind a record or one of its containers. Copies
    // and computed values end the alias rather than being treated as writes.
    for (const match of visible.matchAll(/(?:^|;)[ \t]*(?:var[ \t]+)?(\w+)(?:[ \t]*:[ \t]*[A-Za-z_]\w*)?[ \t]*(?::=|=(?!=))[ \t]*/g)) {
      const start = match.index + match[0].length;
      const rhs = chain(line, start);
      const field = rhs && /^[ \t]*(?:[;\r]|$)/.test(line.slice(rhs.end)) ?
        ownerField(rhs.segments, aliases, stateFields, unitFields) : null;
      if (field && !field.accessLength) aliases.set(match[1], { ...field, depth });
      else aliases.delete(match[1]);
    }
  }
  return writes;
}

export function scan(root, stateOwnership, unitOwnership = {}) {
  const writes = [];
  const walk = directory => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const full = path.join(directory, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.gd')) {
        const file = path.relative(root, full).replaceAll('\\', '/');
        writes.push(...scanSource(file, fs.readFileSync(full, 'utf8'), stateOwnership.fields || {}, unitOwnership.fields || {}));
      }
    }
  };
  for (const layer of ['simulation', 'app', 'presentation']) {
    const directory = path.join(root, layer);
    if (fs.existsSync(directory)) walk(directory);
  }
  for (const file of ['main.gd', 'menu.gd']) {
    const full = path.join(root, file);
    if (fs.existsSync(full)) writes.push(...scanSource(file, fs.readFileSync(full, 'utf8'), stateOwnership.fields || {}, unitOwnership.fields || {}));
  }
  return writes.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
}

// These boundaries decode a fixed wire/schema group, forward a registered
// proxy, or release known record references. Each operation is limited to its
// own call site; repeated or changed dynamic writes still fail the gate.
const BOUNDED_WRITES = {
  'main.gd::_set': {
    kind: 'state', sites: ['state.set(key, value)'], guards: ['if _state_fields.has(key): state.set(key, value)'],
  },
  'simulation/state/battle_state_fields.gd::copy_inputs': {
    kind: 'state', sites: ['target_state.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)'],
    guards: ['for key in INPUTS:'],
  },
  'app/saves/unit_relations.gd::restore': {
    kind: 'unit', sites: [
      'unit[name] = by_uid.get(int(value) if value != null else -1)',
      'unit[name] = _restore_gather_ref(value, by_uid, decor)',
      'unit[name] = Vector2(float(value[0]), float(value[1]))',
      'unit[name] = (value as Array).map(func(point): return Vector2(float(point[0]), float(point[1])))',
    ], guards: ['static var _fields := Schema.fields("relation")', 'for name in _fields:', 'match field.codec:'],
  },
  'simulation/units/unit_schema.gd::restore_scalars': {
    kind: 'unit', sites: ['unit[key] = decode(key,state[key])'], guards: ['for key in fields(group):'],
  },
  'simulation/movement/action_clock.gd::reset': {
    kind: 'unit', sites: ['unit[key] = Schema.default_value(key)'], guards: ['Schema.fields("action")', 'for key in FIELDS:'],
  },
  'simulation/movement/action_clock.gd::restore': {
    kind: 'unit', sites: ['unit[key] = Schema.decode(key, state[key])'], guards: ['Schema.fields("action")', 'for key in FIELDS:'],
  },
  'simulation/movement/locomotion.gd::ensure': {
    kind: 'unit', sites: ['u[key] = (int(u.get("dir",0)) & 7) if key == "move_facing" else Schema.default_value(key)'],
    guards: ['Schema.fields("locomotion")', 'for key in FIELDS:', 'if not u.has(key):'],
  },
  'simulation/movement/locomotion.gd::restore': {
    kind: 'unit', sites: ['u[field] = Schema.decode(field,state[field])'],
    guards: ['Schema.fields("locomotion")', 'for field in FIELDS:'],
  },
  'simulation/movement/tick_timers.gd::restore': {
    kind: 'unit', sites: ['unit[key] = int(state[key])'],
    guards: ['Schema.fields("status")', 'Schema.fields("elapsed")', 'for key in STATUS_KEYS + ELAPSED_KEYS:'],
  },
  'simulation/movement/tick_timers.gd::step_statuses_script': {
    kind: 'unit', sites: ['unit[key]=remaining-1'], guards: ['Schema.fields("status")', 'for key in STATUS_KEYS:'],
  },
  'simulation/world/battle_world.gd::dispose': {
    kind: 'unit', sites: ['unit[field]=null'],
    guards: ['for field in ["target","gather_obj","build_target","repair_target","board_target"]:', 'if unit.get(field) is Dictionary:'],
  },
};

function allowed(write, ownership, dynamic) {
  const field = ownership.fields?.[write.field];
  if (field?.policy === 'READ_ONLY') return false;
  if (write.field === '<dynamic>') {
    const routine = write.file + '::' + write.scope;
    const contract = BOUNDED_WRITES[routine];
    return contract?.kind === write.kind && dynamic.delete(routine + ':' + write.site);
  }
  if (field?.initializer === write.file + '::' + write.scope) return true;
  if (field?.nested_mutation === write.file + '::' + write.scope && write.site.startsWith('_state.map_data.terrainWalkable[')) return true;
  if (field?.restore_sites?.includes(write.file + '::' + write.scope)) return true;
  if (write.owner && write.file.startsWith('simulation/' + write.owner + '/')) return true;
  if (write.kind === 'unit' && field?.restorer === write.file + '::' + write.scope) return true;
  if (write.kind === 'state') {
    if (write.file === SESSION && field?.kind === 'proxy' && write.site.startsWith(field.backing_store)) return true;
    if (write.file === 'simulation/world/battle_world.gd' && write.scope === '_init' &&
        ['geometry', 'simulation_rng'].includes(write.field)) return true;
    if (write.file === RESTORER && field?.restorer === 'snapshot_restorer') return true;
  }
  return false;
}

const signature = ({ file, scope, kind, field, operation, site }) => JSON.stringify([file, scope, kind, field, operation, site]);

export function evaluate(root, stateOwnership, baseline, unitOwnership = {}) {
  const writes = scan(root, stateOwnership, unitOwnership);
  const dynamic = new Set();
  for (const [routine, contract] of Object.entries(BOUNDED_WRITES)) {
    const file = path.join(root, routine.split('::')[0]);
    if (!fs.existsSync(file)) continue;
    const code = fs.readFileSync(file, 'utf8');
    if (contract.guards.every(guard => code.includes(guard))) {
      for (const site of contract.sites) dynamic.add(routine + ':' + site);
    }
  }
  const violations = writes.filter(write => !allowed(write, write.kind === 'unit' ? unitOwnership : stateOwnership, dynamic));
  const unused = new Map();
  for (const entry of baseline.entries || []) {
    const key = signature(entry);
    const matches = unused.get(key) || [];
    matches.push(entry);
    unused.set(key, matches);
  }
  const unbaselined = violations.filter(write => !unused.get(signature(write))?.pop());
  return { writes, violations, unbaselined, stale: [...unused.values()].flat() };
}

function main() {
  const args = process.argv.slice(2);
  const arg = (name, fallback) => {
    const index = args.indexOf(name);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
  };
  const root = arg('--root', 'godot/chibi_remake');
  const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
  const state = read(arg('--ownership', 'tools/inputs/battle_state_ownership.json'));
  const units = read(arg('--unit-ownership', 'tools/inputs/unit_schema_ownership.json'));
  const baselinePath = arg('--baseline', 'tools/inputs/battle_state_write_baseline.json');
  const baseline = read(baselinePath);
  if (baseline.schemaVersion !== 2 || !Array.isArray(baseline.entries) || baseline.entries.length !== 0) {
    throw Error('P7 requires an empty historical write baseline');
  }
  const result = evaluate(root, state, baseline, units);
  console.log('FIELD WRITES: ' + result.writes.length + ' writes, ' + result.violations.length + ' outside owner, ' +
    result.unbaselined.length + ' new, ' + result.stale.length + ' stale');
  for (const write of result.unbaselined.slice(0, 40)) {
    console.error('  NEW ' + write.file + ':' + write.line + ' writes ' + write.kind + '.' + write.field);
  }
  for (const entry of result.stale.slice(0, 40)) console.error('  STALE ' + entry.file + ':' + entry.line + ' ' + entry.field);
  if (result.unbaselined.length || result.stale.length) process.exitCode = 1;
  else console.log('FIELD WRITE OWNERSHIP PASS');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
