import fs from 'node:fs';
import path from 'node:path';

const args=process.argv.slice(2);
const root = (args.includes('--root')?args[args.indexOf('--root')+1]:'godot/chibi_remake').replaceAll('\\','/');
const limitsFile = args.includes('--limits') ? args[args.indexOf('--limits') + 1] : 'tools/inputs/architecture_limits.json';
const limits = JSON.parse(fs.readFileSync(limitsFile, 'utf8'));
const files = directory => fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
  if (entry.name.startsWith('.') || ['art', 'media', 'assets', 'addons', 'data'].includes(entry.name)) return [];
  const file = directory + '/' + entry.name;
  return entry.isDirectory() ? files(file) : file.endsWith('.gd') ? [file] : [];
});
// Recorded debt. Each entry is `<file>::<rule>` and must stay justified: new
// violations fail even though these are tolerated, so the list can only shrink.
const waived = new Set(limits.violations ?? []);
const dependencies = (file, seen = new Set()) => {
  if (seen.has(file)) return seen;
  seen.add(file);
  const full = path.join(root,file);
  if (!fs.existsSync(full)) return seen;
  const source = fs.readFileSync(full,'utf8');
  const code=source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g,(all,string)=>string??'');
  for (const match of code.matchAll(/(?:preload|load)\(\s*(['"])res:\/\/([^'"\n]+\.gd)\1\s*\)/g)) dependencies(match[2],seen);
  return seen;
};
let failures = 0, reviews = 0, waivedHits = 0;
const fail = message => { console.error(message); failures++; };
const today = new Date().toISOString().slice(0, 10);
for (const kind of ['files', 'functions', 'violations']) for (const key of Object.keys(kind === 'violations' ? Object.fromEntries((limits.violations ?? []).map(key => [key, true])) : limits[kind])) {
  const review = limits.reviews?.[kind + ':' + key];
  if (!review?.owner?.trim() || !review?.reason?.trim() || !/^\d{4}-\d{2}-\d{2}$/.test(review?.reviewBy ?? '') || !Number.isFinite(Date.parse(review.reviewBy)) || new Date(review.reviewBy).toISOString().slice(0,10) !== review.reviewBy) fail(`Missing waiver owner/reason/reviewBy: ${kind}:${key}`);
  else if (review.reviewBy < today) fail(`Expired architecture waiver: ${kind}:${key} (${review.owner}, ${review.reviewBy})`);
}
const waive = (key, message) => {
  if (waived.has(key)) waivedHits++;
  else fail(message + ' [' + key + ']');
};
for (const file of files(root)) {
  const relative = path.posix.relative(root, file);
  const source = fs.readFileSync(file, 'utf8');
  const code = source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g,(all,string)=>string??'');
  const executable = code.replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, '""');
  const count = source.trimEnd().split('\n').length;
  if (relative !== 'simulation/battle_world.gd' && /\bworld\.(?:_modules|_access)\b|\bworld\.(?:get|set)\(\s*['"]_(?:modules|access)['"]/.test(code)) fail(`${relative}: accesses private BattleWorld collections`);
  if (['presentation/battle/components/camera_controller.gd','presentation/battle/build_preview.gd','presentation/battle/battle_resources.gd'].includes(relative) && /\bhost\.(?:units|selected|map_data|nav|decor_cells)\b|\bhost(?:\.(?:get|get\.bind)\(\s*|\[\s*)['"](?:units|selected|map_data|nav|decor_cells)['"]/.test(code)) fail(`${relative}: bypasses value read model`);
  if (relative === 'presentation/battle/battle_access.gd' && /\b(?:data|state)\.(?:units|selected|map_data|decor_cells)\.duplicate\(\s*true\s*\)/.test(code)) fail(`${relative}: deep-copies world data at the read boundary`);
  const budget = limits.files[relative] ?? 600;
  if (count > budget) fail(`${relative}: ${count} lines exceeds ${budget}`);
  if (relative.startsWith('simulation/')) {
    if (/\b(?:FileAccess|DirAccess|ResourceLoader|GDExtensionManager|load)\b|\bJSON\s*\.\s*(?:new|parse\w*)\b|\bOS\s*\.\s*(?:execute|execute_with_pipe|create_process)\b/.test(executable)) fail(`${relative}: simulation performs runtime I/O or JSON parsing; load validated rules at startup`);
    const clocks=[...executable.matchAll(/\bTime\b/g)];
    if(clocks.length && !(relative === 'simulation/definitions/profile_clock.gd' && clocks.length === 1 && /^\s*return Time\.get_ticks_usec\(\) if enabled else 0\s*$/m.test(executable))) fail(`${relative}: wall-clock sampling must use opt-in ProfileClock`);
    for(const call of executable.matchAll(/\bProfileClock\s*\.\s*now\s*\(([^)]*)\)/g)){
      if(!['profile_enabled','profile_enabled or timing_enabled'].includes(call[1].trim().replace(/\s+/g,' '))) fail(`${relative}: profiling clock requires an explicit opt-in flag`);
    }
    if (/res:\/\/(app|presentation)\//.test(code)) fail(`${relative}: simulation imports an upper layer`);
    if (/var\s+\w+\s*:\s*(Node2D|Control|CanvasLayer|Camera2D|Sprite2D)\b/.test(code)) fail(`${relative}: simulation retains a scene node`);
    if (/\b(Node2D|Control|CanvasLayer|Camera2D|Sprite2D|AudioStreamPlayer)\.new\(/.test(code)) fail(`${relative}: simulation creates a presentation node`);
    // The simulation must run without a SceneTree: no autoload lookups, no
    // node handles, no `/root/...` paths. Typing a parameter as `Node` was the
    // loophole that let state_digest.gd reach the Game autoload.
    if (/get_node\s*\(|:\s*Node(?:2D)?\b|\/root\//.test(code)) waive(`${relative}::scene-tree`, `${relative}: simulation reaches the scene tree`);
  }
  if (relative.startsWith('app/') && /simulation_rng\.(randi|randf)\s*\(/.test(code)) {
    // Consuming the simulation RNG outside simulation/ puts a gameplay rule in
    // the app layer, where the headless digests cannot cover it. Reading
    // `rngState` for a snapshot stays allowed.
    waive(`${relative}::gameplay-rng`, `${relative}: gameplay randomness rolled outside simulation`);
  }
  if(relative.startsWith('app/') && /\bview\._ui\b/.test(code))fail(`${relative}: app reaches private presentation state`);
  if((relative==='app/save_service.gd'||relative.startsWith('app/saves/')) && /\bview\.(?:unit_nodes|event_view|completion|end_label|projectile_view)\b/.test(code))fail(`${relative}: save pipeline bypasses loaded-view API`);
  if(relative.startsWith('presentation/')&&relative!=='presentation/battle/battle_access.gd'&& /\bhost\.(?:units|selected|map_data|nav|decor_cells|trainings|visibility|clock|projectiles|fire_fields|player_commands|build_types|cmd_pending_data|task_events|terrain_changes)\b|\bhost(?:\.(?:get|get\.bind)\(\s*|\[\s*)['"](?:units|selected|map_data|nav|decor_cells|trainings|visibility|clock|projectiles|fire_fields|player_commands|build_types|cmd_pending_data|task_events|terrain_changes)['"]/.test(code))fail(`${relative}: presentation bypasses value read model`);
  if(relative==='presentation/battle/battle_access.gd'&&/^var (?:units|selected|map_data|nav|decor_cells|trainings|visibility|clock|projectiles|fire_fields|player_commands|build_types|cmd_pending_data|task_events|terrain_changes):/m.test(code))fail(`${relative}: retired mutable getter restored`);
  if(relative==='app/read_models/unit_projection.gd'&&/\b(?:unit|data\.(?:units|selected|map_data))\.duplicate\(\s*true\s*\)/.test(code))fail(`${relative}: copies whole domain records instead of selecting fields`);
  if(relative.startsWith('presentation/') && /\.saver\.apply_snapshot\(|\.selected\.(?:append|clear|erase)\(/.test(code))fail(`${relative}: presentation bypasses session commands`);
  if (relative.startsWith('presentation/') && /(?:preload|load)\(\s*['"]res:\/\/simulation\/systems\//.test(code)) {
    waive(`${relative}::direct-system`, `${relative}: presentation imports a simulation system instead of a port`);
  }
  if (relative.startsWith('presentation/')) {
    for (const dependency of dependencies(relative)) {
      if (/^simulation\/(systems|navigation|battle)\//.test(dependency) || /^simulation\/battle_(state|world)\.gd$/.test(dependency)) {
        fail(`${relative}: transitive mutable simulation dependency ${dependency}`);
      }
    }
  }
  if (relative.startsWith('simulation/') && /res:\/\/(app|presentation)\//.test([...dependencies(relative)].join('\n'))) fail(`${relative}: transitive upper layer dependency`);
  if (relative.startsWith('presentation/battle/components/')) {
    if (/\b(?:host|u|unit)\.(?:hp|alive|target|path|gold|wood|food|stone|attached)\s*=(?!=)/.test(code)) fail(`${relative}: presentation writes gameplay state`);
  }
  const functions = [...source.matchAll(/^(?:static )?func\s+(\w+)\(/gm)];
  for (let i = 0; i < functions.length; i++) {
    const fn = functions[i];
    const remainder = source.slice(fn.index);
    const firstLine = remainder.indexOf('\n');
    const nextDeclaration = /^(?:var|const|signal|class|extends|(?:static )?func)\b/m.exec(remainder.slice(firstLine + 1));
    const body = remainder.slice(0, nextDeclaration ? firstLine + 1 + nextDeclaration.index : remainder.length).trimEnd();
    const length = body.split('\n').length;
    if (length <= 80) continue;
    const key = relative + '::' + fn[1];
    const existing = limits.functions[key];
    if (!existing || length > existing) fail(`${key}: ${length} lines; review required (budget ${existing ?? 80})`);
    reviews++;
  }
}
if (failures) process.exitCode = 1;
else console.log(`ARCHITECTURE PASS layers / state ownership / file budgets; ${reviews} preserved long functions tracked for review; ${waivedHits} recorded debt item(s)`);
