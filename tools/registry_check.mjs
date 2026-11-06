import fs from 'node:fs';
import path from 'node:path';
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
  if(!report?.[name]||report[name].missing.length||report[name].conflicts.length)throw Error('Invalid '+name);
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
 const providers=manifest.hosts[entry.host];
 for(const [provider,requirements] of Object.entries(declared)){
  if(!providers[provider])throw Error(file+': unknown provider '+provider);
  const provided=methods(providers[provider]);
  for(const method of requirements){if(!provided.has(method))throw Error(file+': '+provider+'.'+method+' missing');bindings++;}
 }
 for(const call of text.matchAll(/_require\(_provider_(\w+), "[^"]+"\)\.(\w+)\(/g)){
  if(!declared[call[1]]?.includes(call[2]))throw Error(file+': undeclared direct call '+call[1]+'.'+call[2]);
 }
}
const commandMethods=methods('app/battle_commands.gd');
for(const call of read('presentation/battle/battle_access.gd').matchAll(/_commands.get_ref\(\)\.(\w+)\(/g))if(!commandMethods.has(call[1]))throw Error('Missing presentation command '+call[1]);
for(const retired of ['registry.gd','simulation/ports/capability_links.gd','app/battle_facade.gd'])if(fs.existsSync(path.join(root,retired)))throw Error('Retired dispatch still exists: '+retired);
console.log(`REGISTRY PASS ${Object.keys(manifest.ports).length} named ports / ${bindings} checked provider methods / no reflection dispatch`);
