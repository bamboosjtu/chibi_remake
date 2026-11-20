import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const root=option('--root','godot/chibi_remake');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const manifest=JSON.parse(fs.readFileSync('tools/inputs/composition.json','utf8'));
if(args.includes('--runtime-log')){
 const log=fs.readFileSync(option('--runtime-log'),'utf8');
 if(/SCRIPT ERROR:|contract validation failed/.test(log))throw Error('Invalid runtime composition');
 const report=JSON.parse(log.match(/^COMPOSITION JSON: (.+)$/m)?.[1]??'null');
 for(const name of ['main','view','menu','nav']){
  if(!report?.[name]||report[name].missing.length)throw Error('Invalid '+name);
  const actual=Object.fromEntries(Object.entries(report[name].services).map(([key,file])=>[key,file.replace(/^res:\/\//,'')]));
  const expected = {...manifest.hosts[name]};
  if (name === 'menu' && Object.hasOwn(actual, 'automation_driver')) expected.automation_driver = 'app/automation/menu_driver.gd';
  assert.deepEqual(actual,expected,name+': runtime services differ from composition manifest');
  console.log('REGISTRY '+name+' PASS concrete runtime service scripts');
 }
 process.exit(0);
}
// Check every explicit peer installed by the composition roots. The consumer
// calls these fields directly, so member resolution is possible without a
// second manually maintained list of methods.
const rootFiles = {
 main: ['simulation/world/battle_world.gd', 'main.gd'],
 menu: ['menu.gd'],
 view: ['presentation/battle/view/battle_view.gd'],
 nav: ['simulation/navigation/nav.gd'],
};
for (const [name, files] of Object.entries(rootFiles)) {
 const owners = {...manifest.hosts[name]};
 if (name === 'menu') owners.automation_driver = 'app/automation/menu_driver.gd';
 const wiring = files.map(read).join('\n');
 for (const [service, file] of Object.entries(owners)) {
  // Require the named factory itself, not a substring of it: `rules` matched
  // `command_rules` before, so a missing or renamed factory could pass.
  const target = 'res://' + file.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const aliases = [...wiring.matchAll(new RegExp('const\\s+(\\w+)\\s*=\\s*(?:preload|load)\\(\\s*"' + target + '"', 'g'))].map(match => match[1]);
  const sources = ['(?:preload|load)\\(\\s*"' + target + '"\\s*\\)', ...aliases].join('|');
  assert(new RegExp('^\\s*(?:var\\s+)?' + service + '\\s*(?::=|=)\\s*(?:' + sources + ')\\s*\\.new\\(', 'm').test(wiring),
   name + ': missing factory for ' + service + ' -> ' + file);
  const code = read(file);
  for (const match of code.matchAll(/\b_dep_(\w+)\.(\w+)\b/g)) {
   const [, peer, method] = match;
   assert(owners[peer] && new RegExp('^func ' + method + '\\(', 'm').test(read(owners[peer])), file + ': missing ' + peer + '.' + method);
  }
 }
}
for(const file of ['simulation/state/battle_state.gd','app/battle_scene_state.gd','presentation/menu/menu_state.gd','presentation/battle/view/battle_view_state.gd','simulation/navigation/navigation_state.gd','simulation/ai/ai_state.gd']){
 const source=read(file),declared=JSON.parse(source.match(/^const PROXY_FIELDS := (.+)$/m)?.[1]??'null');
 assert.deepEqual(declared,[...source.matchAll(/^var (\w+)/gm)].map(m=>m[1]),file+': explicit property surface is stale');
}
for(const retired of ['registry.gd','simulation/ports/capability_links.gd','app/battle_facade.gd','app/saves/legacy_snapshot.gd','app/saves/legacy_seed.gd','data/db/rules_contract.json','data/db/registry_compatibility.json'])if(fs.existsSync(path.join(root,retired)))throw Error('Retired implementation still exists: '+retired);
// Resolve direct `world.<service>.<member>(...)` calls from the application and
// presentation layers. These calls are untyped, so without this a renamed or removed
// member only surfaces at run time in front of the player.
const worldOwners = {...manifest.hosts.main};
const worldKeys = Object.keys(worldOwners);
const gdFiles = dir => fs.readdirSync(path.join(root, dir), {withFileTypes: true}).flatMap(entry =>
 entry.isDirectory() ? gdFiles(path.join(dir, entry.name)) : entry.name.endsWith('.gd') ? [path.join(dir, entry.name).replaceAll('\\', '/')] : []);
const unresolved = [];
for (const file of [...gdFiles('app'), ...gdFiles('presentation')]) {
 const code = fs.readFileSync(path.join(root, file), 'utf8').replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g, (all, string) => string ?? '');
 for (const match of code.matchAll(/\bworld\.(\w+)\.(\w+)\s*\(/g)) {
  const [, service, member] = match;
  if (!worldKeys.includes(service)) continue;
  if (!new RegExp('^(?:static )?func ' + member + '\\(', 'm').test(read(worldOwners[service])))
   unresolved.push(file + ': world.' + service + '.' + member + ' missing in ' + worldOwners[service]);
 }
}
assert.deepEqual(unresolved, [], 'unresolved world member calls:\n' + unresolved.join('\n'));
console.log('REGISTRY PASS concrete factories / direct peer methods / resolved world members / registered state fields');
