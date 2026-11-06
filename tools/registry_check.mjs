import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const root=option('--root','godot/chibi_remake');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const manifest=JSON.parse(fs.readFileSync('tools/inputs/composition.json','utf8'));
function methods(file,seen=new Set()){
 if(seen.has(file))return new Set();seen.add(file);
 const text=read(file),result=new Set([...text.matchAll(/^(?:static )?func (\w+)\(/gm)].map(m=>m[1]));
 const base=text.match(/^extends "res:\/\/([^\"]+)"/m);
 if(base)for(const method of methods(base[1],seen))result.add(method);
 return result;
}
if(args.includes('--runtime-log')){
 const log=fs.readFileSync(option('--runtime-log'),'utf8');
 if(/SCRIPT ERROR:|explicit port contract failed/.test(log))throw Error('Invalid runtime composition');
 const report=JSON.parse(log.match(/^COMPOSITION JSON: (.+)$/m)?.[1]??'null');
 for(const name of ['main','view','menu','nav']){
  if(!report?.[name]||report[name].missing.length)throw Error('Invalid '+name);
  const actual=Object.fromEntries(Object.entries(report[name].services).map(([key,file])=>[key,file.replace(/^res:\/\//,'')]));
  assert.deepEqual(actual,manifest.hosts[name],name+': runtime services differ from composition manifest');
  console.log('REGISTRY '+name+' PASS explicit runtime provider contracts');
 }
 process.exit(0);
}
let bindings=0;
for(const [file,entry] of Object.entries(manifest.ports)){
 const text=read(file);
 if(/\b(?:invoke|api\.get)\(|var _fn\w*\s*:/.test(text))throw Error(file+': obsolete dispatch');
 const declared=JSON.parse(text.match(/^const CONTRACTS := (.+)$/m)?.[1]??'null');
 if(!declared)throw Error(file+': missing explicit contract');
 if('providers' in entry)throw Error(file+': remove duplicated providers from composition.json; CONTRACTS in the port source is authoritative');
 const providers=manifest.hosts[entry.host];
 for(const [provider,requirements] of Object.entries(declared)){
  if(!providers[provider])throw Error(file+': unknown provider '+provider);
  const provided=methods(providers[provider]);
  for(const method of requirements){if(!provided.has(method))throw Error(file+': '+provider+'.'+method+' missing');bindings++;}
 }
 // Ignore comments, preserving quoted provider names. Guard layout may use
 // spaces/tabs, line breaks, blank lines or comments between the statements.
 const code=text.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g,(all,string)=>string??'');
 for(const wrapper of code.matchAll(/^func \w+\([\s\S]*?(?=^(?:func|const|var)\b|(?![\s\S]))/gm)){
  const body=wrapper[0];
  const binding=body.match(/var\s+provider\s*(?::\s*\w+\s*)?=\s*_require\s*\(\s*_provider_(\w+)\s*,\s*(["'])(\w+)\2\s*\)/);
  if(!binding){if(/\b_require\s*\(/.test(body))throw Error(file+': unrecognized provider binding');continue;}
  const guard=body.match(/^([ \t]+)if\s+provider\s*==\s*null\s*:[ \t]*(?:return\b|\r?\n\s*?([ \t]+)return\b)/m);
  const indent=s=>s.replaceAll('\t','    ').length;
  const guarded=guard && (!guard[2]||indent(guard[2])>indent(guard[1])) && guard.index>binding.index;
  if(binding[1]!==binding[3]||!guarded)throw Error(file+': unguarded provider');
  for(const call of body.matchAll(/provider\s*\.\s*(\w+)\s*\(/g)){
   if(call.index<guard.index+guard[0].length)throw Error(file+': provider called before lifetime guard');
   if(!declared[binding[1]]?.includes(call[1]))throw Error(file+': undeclared direct call '+binding[1]+'.'+call[1]);
  }
 }
}
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.name.startsWith('.')||['art','media','data','assets','addons'].includes(e.name)?[]:e.isDirectory()?walk(path.join(dir,e.name)):e.name.endsWith('.gd')?[path.join(dir,e.name)]:[]);}
for(const file of walk(root))for(const call of fs.readFileSync(file,'utf8').matchAll(/\bcommands\.(\w+)\.(\w+)\b/g)){
 if(!methods('app/commands/'+call[1]+'_commands.gd').has(call[2]))throw Error(file+': missing domain command '+call[1]+'.'+call[2]);
}
for(const file of walk(root)){
 const relative=path.relative(root,file).split(path.sep).join('/');
 if(fs.readFileSync(file,'utf8').startsWith('extends "res://named_port.gd"')&&!manifest.ports[relative])throw Error('Port outside composition coverage: '+relative);
}
// Cross-check literal factory declarations before the engine runs as well.
for(const [host,files,variable] of [['main',['simulation/battle_world.gd','main.gd'],'(?:_modules|_application_services)'],['view',['presentation/battle/battle_view.gd'],'_components'],['menu',['menu.gd'],'_components']]){
 const actual={};for(const file of files)for(const m of read(file).matchAll(new RegExp(variable+'\\["([^"]+)"\\] = preload\\("res://([^"]+)"\\)','g')))actual[m[1]]=m[2];
 assert.deepEqual(actual,manifest.hosts[host],host+': factory services differ from composition manifest');
}
const nav={};for(const m of read('simulation/navigation/nav.gd').matchAll(/^var (grid|paths) = preload\("res:\/\/([^\"]+)"\)/gm))nav[m[1]]=m[2];
assert.deepEqual(nav,manifest.hosts.nav,'nav: factory services differ from composition manifest');
for(const file of ['simulation/battle_state.gd','app/battle_scene_state.gd','presentation/menu/menu_state.gd','presentation/battle/components/battle_view_state.gd','simulation/navigation/navigation_state.gd','simulation/systems/ai_state.gd']){
 const source=read(file),declared=JSON.parse(source.match(/^const PROXY_FIELDS := (.+)$/m)?.[1]??'null');
 assert.deepEqual(declared,[...source.matchAll(/^var (\w+)/gm)].map(m=>m[1]),file+': explicit property surface is stale');
}
for(const retired of ['registry.gd','simulation/ports/capability_links.gd','app/battle_facade.gd'])if(fs.existsSync(path.join(root,retired)))throw Error('Retired dispatch still exists: '+retired);
console.log(`REGISTRY PASS ${Object.keys(manifest.ports).length} named ports / ${bindings} checked provider methods / no reflection dispatch`);
