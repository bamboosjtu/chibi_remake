import fs from 'node:fs';
import path from 'node:path';

const root = 'godot/chibi_remake';
const limits = JSON.parse(fs.readFileSync('tools/inputs/architecture_limits.json', 'utf8'));
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
  for (const match of source.matchAll(/(?:preload|load)\("res:\/\/([^"\n]+\.gd)"\)/g)) dependencies(match[1],seen);
  return seen;
};
let failures = 0, reviews = 0, waivedHits = 0;
const fail = message => { console.error(message); failures++; };
const waive = (key, message) => {
  if (waived.has(key)) waivedHits++;
  else fail(message + ' [' + key + ']');
};
for (const file of files(root)) {
  const relative = path.posix.relative(root, file);
  const source = fs.readFileSync(file, 'utf8');
  const code = source.split('\n').map(line => line.replace(/#.*/, '')).join('\n');
  const count = source.trimEnd().split('\n').length;
  const budget = limits.files[relative] ?? 600;
  if (count > budget) fail(`${relative}: ${count} lines exceeds ${budget}`);
  if (relative.startsWith('simulation/')) {
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
  if (relative.startsWith('presentation/') && /preload\("res:\/\/simulation\/systems\//.test(code)) {
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
