#!/usr/bin/env node
// Static dependency evidence for the chibi_remake GDScript tree.
// This is a baseline tool: it never rewrites project files.
//
// Usage:
//   node tools/dependency_report.mjs [--root godot/chibi_remake] [--map tools/inputs/module_map.json]
//        [--matrix tools/inputs/dependency_matrix.json] [--baseline tools/inputs/dependency_baseline.json]
//        [--output _work/refactor/dependency-graph.json] [--check] [--quiet]
//
// Exit codes: 0 report/check pass, 1 check failed, 2 usage/tool error.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import { sourceViews } from './lib/gdscript_source.mjs';

function fail(message) {
  const err = new Error(message);
  err.code = 'DEPENDENCY_REPORT';
  throw err;
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.gd')) out.push(full);
  }
  return out;
}

function lineText(text, index) {
  const start = text.lastIndexOf('\n', index) + 1;
  const end = text.indexOf('\n', index);
  return text.slice(start, end < 0 ? text.length : end).trim().slice(0, 160);
}

const SERVICE_PACKAGE = {
  state: 'simulation/state', geometry: 'simulation/navigation', nav: 'simulation/navigation',
  economy: 'simulation/economy', production: 'simulation/production', technology: 'simulation/technology',
  combat: 'simulation/combat', movement: 'simulation/movement', transports: 'simulation/transport',
  transport_orders: 'simulation/transport', construction: 'simulation/construction',
  construction_orders: 'simulation/construction', commands: 'simulation/commands',
  world_orders: 'simulation/commands', player_commands: 'simulation/commands',
  command_groups: 'simulation/commands', selection: 'simulation/commands',
  ai: 'simulation/ai', ai_economy: 'simulation/ai', ai_orders: 'simulation/ai',
  officer_pool: 'simulation/officers', officer_teams: 'simulation/officers',
  officer_progression: 'simulation/officers', scenario_rules: 'simulation/scenario',
  campaign: 'simulation/scenario', cheats: 'simulation/cheats', effects: 'simulation/ports',
  visibility: 'simulation/visibility', battle_visibility: 'simulation/visibility',
  projectiles: 'simulation/combat', fire_fields: 'simulation/combat', engagement: 'simulation/combat',
  stratagems: 'simulation/combat', harvesting: 'simulation/economy', harvest_orders: 'simulation/economy',
  interaction_paths: 'simulation/navigation', spatial_index: 'simulation/navigation',
  unit_footprint: 'simulation/navigation', navigation: 'simulation/navigation',
  technologies: 'simulation/technology', technology_state: 'simulation/technology',
  rules: 'simulation/scenario', opening: 'app/battle', bootstrap: 'app/battle',
};

export function analyze(opts = {}) {
  const root = opts.root || 'godot/chibi_remake';
  const mapPath = opts.map || 'tools/inputs/module_map.json';
  const matrixPath = opts.matrix || 'tools/inputs/dependency_matrix.json';
  const baselinePath = opts.baseline || 'tools/inputs/dependency_baseline.json';
  if (!fs.existsSync(root)) fail(`root not found: ${root}`);
  const projectRoot = path.resolve(root);
  const files = walk(projectRoot).map((f) => path.relative(projectRoot, f).replaceAll('\\', '/')).sort();
  const fileSet = new Set(files);

  const moduleMap = fs.existsSync(mapPath) ? JSON.parse(fs.readFileSync(mapPath, 'utf8')) : { entries: [] };
  const targetOf = new Map();
  for (const e of moduleMap.entries || []) targetOf.set(e.from, e);
  const targetPath = (rel) => targetOf.get(rel)?.to || rel;

  function packageOf(rel) {
    if (!rel || !rel.includes('/')) return 'root';
    if (rel.startsWith('app/battle/')) return 'app/battle';
    if (rel.startsWith('app/saves/')) return 'app/saves';
    if (rel.startsWith('app/read_models/')) return 'app/read_models';
    if (rel.startsWith('app/rules/')) return 'app/rules';
    if (rel.startsWith('app/campaign/')) return 'app/campaign';
    if (rel.startsWith('app/')) return 'app';
    if (rel.startsWith('presentation/')) return 'presentation';
    if (rel.startsWith('testing/')) return 'testing';
    if (rel.startsWith('simulation/definitions/')) return 'simulation/definitions';
    const seg = rel.split('/');
    if (seg.length < 2) return seg[0];
    return seg.slice(0, 2).join('/');
  }

  const targetPackage = (rel) => targetOf.get(rel)?.package || packageOf(rel);
  const sourcePackage = (rel) => {
    const current = packageOf(rel);
    const target = targetPackage(rel);
    const top = (p) => (p ? p.split('/')[0] : '');
    return top(current) !== top(target) ? current : target;
  };

  const edges = [];
  for (const rel of files) {
    const {uncommented: text, code} = sourceViews(fs.readFileSync(path.join(projectRoot, rel), 'utf8'));
    for (const [re, kind, confidence] of [
      [/\b(?:preload|load)\s*\(\s*(['"])res:\/\/([^'"\r\n]+\.gd)\1\s*\)/g, 'import', 'confirmed'],
      [/\bextends\s+(['"])res:\/\/([^'"\r\n]+\.gd)\1/g, 'extends', 'confirmed'],
    ]) {
      for (const m of text.matchAll(re)) {
        if (code[m.index] !== text[m.index]) continue;
        const target = m[2].replaceAll('\\', '/');
        if (!fileSet.has(target)) continue;
        edges.push({ from: rel, to: target, kind, confidence, line: text.slice(0, m.index).split('\n').length, evidence: m[0].trim() });
      }
    }
    for (const m of text.matchAll(/\b(?:load|preload)\s*\((?!\s*['"])/g)) {
      if (code[m.index] !== text[m.index]) continue;
      edges.push({ from: rel, to: null, kind: 'dynamic-load', confidence: 'dynamic', line: text.slice(0, m.index).split('\n').length, evidence: lineText(text, m.index) });
    }
    for (const m of text.matchAll(/(_dep_\w+)\s*=\s*(\w+)\.(\w+)/g)) {
      edges.push({ from: rel, to: null, kind: 'dep-binding', confidence: 'inferred', line: text.slice(0, m.index).split('\n').length, evidence: m[0].trim(), service: m[3] });
    }
    for (const m of text.matchAll(/\bworld\.(\w+)\.(\w+)/g)) {
      edges.push({ from: rel, to: null, kind: 'world-call', confidence: 'inferred', line: text.slice(0, m.index).split('\n').length, evidence: m[0].trim(), service: m[1] });
    }
    for (const m of text.matchAll(/(\w+)\.new\(\s*(?:self|world|h)\s*\)/g)) {
      edges.push({ from: rel, to: null, kind: 'constructor-injection', confidence: 'inferred', line: text.slice(0, m.index).split('\n').length, evidence: m[0].trim() });
    }
    const initMatch = text.match(/func\s+_init\s*\(\s*(\w+)\s*:\s*Object\s*\)/);
    if (initMatch) {
      const param = initMatch[1];
      for (const m of text.matchAll(new RegExp(`\\b${param}\\.(\\w+)`, 'g'))) {
        edges.push({ from: rel, to: null, kind: 'constructor-read', confidence: 'inferred', line: text.slice(0, m.index).split('\n').length, evidence: m[0].trim(), service: m[1] });
      }
      edges.push({ from: rel, to: null, kind: 'world-held', confidence: 'inferred', line: text.slice(0, initMatch.index).split('\n').length, evidence: `_init(${param}: Object)` });
    }
    for (const m of text.matchAll(/\.(?:call|get)\(|Callable\(|\bscene\.view\b/g)) {
      edges.push({ from: rel, to: null, kind: 'dynamic', confidence: 'dynamic', line: text.slice(0, m.index).split('\n').length, evidence: lineText(text, m.index) });
    }
  }

  const resolved = edges.map((e) => {
    if (e.to || !e.service) return e;
    const pkg = SERVICE_PACKAGE[e.service];
    return pkg ? { ...e, toPackageHint: pkg } : e;
  });

  const packageEdges = new Map();
  for (const e of resolved) {
    const fromPkg = sourcePackage(e.from);
    const toPkg = e.to ? targetPackage(e.to) : e.toPackageHint;
    if (!toPkg) continue;
    const key = `${fromPkg}\u0000${toPkg}\u0000${e.kind}`;
    if (!packageEdges.has(key)) packageEdges.set(key, { fromPackage: fromPkg, toPackage: toPkg, kind: e.kind, confidence: e.confidence, count: 0, samples: [] });
    const row = packageEdges.get(key);
    row.count += 1;
    if (row.samples.length < 3) row.samples.push({ from: e.from, to: e.to, line: e.line, evidence: e.evidence });
  }

  const confirmed = resolved.filter((e) => e.to && e.confidence === 'confirmed');
  const adj = new Map(files.map((f) => [f, new Set()]));
  for (const e of confirmed) adj.get(e.from)?.add(e.to);
  let index = 0;
  const indices = new Map(), low = new Map(), stack = [], onStack = new Set(), sccs = [];
  function strongconnect(v) {
    indices.set(v, index); low.set(v, index); index += 1;
    stack.push(v); onStack.add(v);
    for (const w of adj.get(v) || []) {
      if (!indices.has(w)) { strongconnect(w); low.set(v, Math.min(low.get(v), low.get(w))); }
      else if (onStack.has(w)) low.set(v, Math.min(low.get(v), indices.get(w)));
    }
    if (low.get(v) === indices.get(v)) {
      const comp = [];
      let w;
      do { w = stack.pop(); onStack.delete(w); comp.push(w); } while (w !== v);
      if (comp.length > 1 || adj.get(v).has(v)) sccs.push(comp.sort());
    }
  }
  for (const f of files) if (!indices.has(f)) strongconnect(f);
  sccs.sort((a, b) => b.length - a.length || a[0].localeCompare(b[0]));

  const matrix = fs.existsSync(matrixPath) ? JSON.parse(fs.readFileSync(matrixPath, 'utf8')) : { packages: {} };
  const baseline = fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, 'utf8')) : { edges: [] };
  const cycles = sccs.map(members => {
    const contained = new Set(members);
    return {members, references: confirmed.filter(e => contained.has(e.from) && contained.has(e.to))};
  });
  const cycleKey = (members, edges) => JSON.stringify([
    [...members].sort(), [...new Set(edges.map(({from, to}) => JSON.stringify([from, to])))].sort(),
  ]);
  const registeredCycles = new Map();
  for (const cycle of baseline.cycles ?? []) {
    if (!Array.isArray(cycle.members) || cycle.members.length === 0 || !Array.isArray(cycle.edges) || !cycle.reason?.trim()
        || cycle.edges.some(edge => !cycle.members.includes(edge.from) || !cycle.members.includes(edge.to))) {
      fail('Invalid dependency cycle baseline');
    }
    const key = cycleKey(cycle.members, cycle.edges);
    if (registeredCycles.has(key)) fail('Duplicate dependency cycle baseline');
    registeredCycles.set(key, cycle);
  }
  const newCycles = cycles.filter(cycle => !registeredCycles.delete(cycleKey(cycle.members, cycle.references)));
  const exceptions = new Map((matrix.fileExceptions || []).map((e) => [e.file, new Set(e.allow || [])]));

  function allowed(fromPkg, toPkg) {
    if (fromPkg === toPkg) return true;
    if (fromPkg === 'root' || fromPkg === 'testing') return true;
    const rule = matrix.packages?.[fromPkg];
    if (!rule) return false;
    return (rule.allow || []).some((a) => a === '*' || toPkg === a || toPkg.startsWith(`${a}/`));
  }
  const exceptionAllows = (file, toPkg) => {
    const allow = exceptions.get(file);
    return !!allow && [...allow].some((a) => toPkg === a || toPkg.startsWith(`${a}/`));
  };

  const violations = [];
  for (const e of resolved) {
    const fromPkg = sourcePackage(e.from);
    const toPkg = e.to ? targetPackage(e.to) : e.toPackageHint;
    if (!toPkg || fromPkg === toPkg) continue;
    if (allowed(fromPkg, toPkg)) continue;
    const rule = matrix.packages?.[fromPkg];
    if (rule?.allowFiles?.includes(e.to ? targetPath(e.to) : '')) continue;
    if (exceptionAllows(e.from, toPkg)) continue;
    violations.push({ from: e.from, to: e.to, fromPackage: fromPkg, toPackage: toPkg, kind: e.kind, confidence: e.confidence, line: e.line, evidence: e.evidence });
  }

  const baselineEdges = baseline.edges || [];
  const matchedBaseline = new Set();
  const unbaselined = [];
  for (const v of violations) {
    const fromCandidates = [v.from, targetPath(v.from)];
    const toCandidates = v.to ? [v.to, targetPath(v.to)] : [null];
    const hit = baselineEdges.findIndex((b) => !matchedBaseline.has(b) && fromCandidates.includes(b.from) && (b.to === null || toCandidates.includes(b.to)) && (!b.fromPackage || b.fromPackage === v.fromPackage || b.fromPackage === sourcePackage(v.from)));
    if (hit >= 0) matchedBaseline.add(baselineEdges[hit]);
    else unbaselined.push(v);
  }
  const staleBaseline = baselineEdges.filter((b) => !matchedBaseline.has(b));

  return {
    generatedAt: new Date().toISOString(),
    root,
    files: files.length,
    edges: resolved.length,
    confirmedEdges: confirmed.length,
    dynamicEdges: resolved.filter((e) => e.confidence === 'dynamic').length,
    unresolvedEdges: resolved.filter((e) => !e.to && !e.toPackageHint).length,
    packageEdges: [...packageEdges.values()].sort((a, b) => b.count - a.count),
    sccs,
    cycles,
    newCycles,
    staleCycles: [...registeredCycles.values()],
    violations,
    unbaselined,
    baseline: { total: baselineEdges.length, matched: matchedBaseline.size, stale: staleBaseline.length },
    staleBaseline,
    fileExceptions: matrix.fileExceptions || [],
  };
}

export function printCycles(summary) {
  for (const cycle of summary.cycles) {
    console.log('  SCC: ' + cycle.members.join(', '));
    for (const {from, to, line} of cycle.references) console.log('    ' + from + ':' + line + ' -> ' + to);
  }
}

export function checkDependencies(summary) {
  const errors = [];
  for (const v of summary.unbaselined) errors.push('Unbaselined edge: ' + v.from + ':' + v.line + ' -> ' + (v.to ?? v.toPackage));
  for (const b of summary.staleBaseline) errors.push('Stale baseline edge: ' + b.from + ' -> ' + b.to);
  for (const cycle of summary.newCycles) errors.push('Unbaselined SCC: ' + cycle.members.join(', '));
  for (const cycle of summary.staleCycles) errors.push('Stale SCC baseline: ' + cycle.members.join(', '));
  return errors;
}

function main() {
  const args = process.argv.slice(2);
  const arg = (name, fallback) => {
    const i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  };
  const check = args.includes('--check');
  const quiet = args.includes('--quiet');
  const output = arg('--output', '_work/refactor/dependency-graph.json');
  let summary;
  try {
    summary = analyze({
      root: arg('--root', 'godot/chibi_remake'),
      map: arg('--map', 'tools/inputs/module_map.json'),
      matrix: arg('--matrix', 'tools/inputs/dependency_matrix.json'),
      baseline: arg('--baseline', 'tools/inputs/dependency_baseline.json'),
    });
  } catch (err) {
    console.error(`DEPENDENCY REPORT ERROR: ${err.message}`);
    process.exit(2);
  }
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, JSON.stringify(summary, null, 2) + '\n');
  if (!quiet) {
    console.log(`DEPENDENCY REPORT: ${summary.files} files, ${summary.edges} edges (${summary.confirmedEdges} confirmed, ${summary.dynamicEdges} dynamic, ${summary.unresolvedEdges} unresolved)`);
    console.log(`SCC: ${summary.sccs.length} components (largest ${summary.sccs[0]?.length || 0})`);
    console.log(`VIOLATIONS: ${summary.violations.length} (baselined ${summary.baseline.matched}, unbaselined ${summary.unbaselined.length}, stale baseline ${summary.baseline.stale})`);
    printCycles(summary);
    for (const v of summary.unbaselined.slice(0, 25)) console.log(`  NEW ${v.fromPackage} -> ${v.toPackage} ${v.from}:${v.line} (${v.kind})`);
    for (const b of summary.staleBaseline.slice(0, 25)) console.log(`  STALE ${b.from} -> ${b.to} (${b.reason || ''})`);
  }
  if (check) {
    const errors = checkDependencies(summary);
    if (errors.length) {
      console.error('DEPENDENCY CHECK FAIL:\n' + errors.join('\n'));
      process.exit(1);
    }
    console.log('DEPENDENCY CHECK PASS');
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) main();
