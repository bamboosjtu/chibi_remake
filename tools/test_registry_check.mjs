import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/registry-fixtures');fs.mkdirSync(parent,{recursive:true});const fixture=fs.mkdtempSync(parent+'/named-');
function copy(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||['art','assets','media','data','addons'].includes(e.name))continue;const r=path.join(rel,e.name);if(e.isDirectory())copy(path.join(dir,e.name),r);else if(e.name.endsWith('.gd')){fs.mkdirSync(path.dirname(path.join(fixture,r)),{recursive:true});fs.writeFileSync(path.join(fixture,r),fs.readFileSync(path.join(dir,e.name),'utf8').replaceAll('\r\n','\n'));}}}
const run=()=>spawnSync(process.execPath,['tools/registry_check.mjs','--root',fixture],{encoding:'utf8'});
try{copy('godot/chibi_remake');assert.equal(run().status,0);
 const port=path.join(fixture,'simulation/ports/technology_dependencies.gd'),source=fs.readFileSync(port,'utf8');
 for(const guard of ['if provider == null:\n\t\treturn','if provider == null: # safe teardown\n\n\t\t# no dereference\n\t\treturn','if  provider==null:\n        return']){
  fs.writeFileSync(port,source.replace('if provider == null: return',guard));assert.equal(run().status,0,guard);
 }
 fs.writeFileSync(port,source);
 // An additional source contract needs no duplicate manifest entry.
 const extra=source.replace('const CONTRACTS := {','const CONTRACTS := {"technology": ["tech_is_sell"], ').replace('var _provider_battle_simulation: WeakRef','var _provider_battle_simulation: WeakRef\nvar _provider_technology: WeakRef')+'\nfunc added_query(idx: int) -> bool:\n\tvar provider = _require(_provider_technology, "technology")\n\tif provider == null:\n\t\treturn false\n\treturn provider.tech_is_sell(idx)\n';
 fs.writeFileSync(port,extra);assert.equal(run().status,0,'source-only contract extension');
 fs.writeFileSync(port,extra.replace('"tech_is_sell"','"__missing_method"'));assert.notEqual(run().status,0,'invalid source-only contract');
 fs.writeFileSync(port,source);
 for(const [file,change] of [
  ['simulation/ports/abilities_dependencies.gd',s=>s.replace('"_kill"','"__missing_method"')],
  ['simulation/ports/technology_dependencies.gd',s=>s.replace('if provider == null: return','# if provider == null: return')],
  ['simulation/ports/technology_dependencies.gd',s=>s.replace('if provider == null: return','if provider == null:\n\treturn')],
  ['simulation/ports/technology_dependencies.gd',s=>s.replace('if provider == null: return\n\tprovider._feedback(msg)','provider._feedback(msg)\n\tif provider == null: return')],
  ['simulation/ports/ai_access.gd',s=>s+'\nvar _fn_legacy: Callable\n'],
  ['app/commands/technology_commands.gd',s=>s.replace('provider.tech_is_sell','provider.__missing_command')],
  ['main.gd',s=>s.replace('_modules.merge(_application_services)','_modules["undeclared"] = preload("res://app/battle/bootstrap.gd").new()\n\t_modules.merge(_application_services)')],
  ['simulation/battle_state.gd',s=>s+'\nvar undeclared_property: int\n'],
  ['presentation/battle/components/hud_input.gd',s=>s.replace('commands.session.handle_cheat_input','commands.session.__missing_command')]
 ]){const p=path.join(fixture,file),old=fs.readFileSync(p,'utf8'),changed=change(old);assert.notEqual(changed,old,'Fixture mutation had no effect: '+file);fs.writeFileSync(p,changed);assert.notEqual(run().status,0,file);fs.writeFileSync(p,old);}
 console.log('REGISTRY NEGATIVE PASS missing provider method / retired dispatch / missing presentation command');
 console.log('PORT SOURCE PASS single contract source / multiline guards; comments, wrong indentation and late guards rejected');
 const manifest=JSON.parse(fs.readFileSync('tools/inputs/composition.json','utf8'));
 const report=Object.fromEntries(Object.entries(manifest.hosts).map(([name,services])=>[name,{missing:[],services:Object.fromEntries(Object.entries(services).map(([key,file])=>[key,'res://'+file]))}]));
 const log=path.join(fixture,'composition.log');
 const runtime=()=>{fs.writeFileSync(log,'COMPOSITION JSON: '+JSON.stringify(report)+'\n');return spawnSync(process.execPath,['tools/registry_check.mjs','--runtime-log',log],{encoding:'utf8'});};
 assert.equal(runtime().status,0);
 const original=report.main.services.abilities;
 report.main.services.abilities='res://wrong.gd';assert.notEqual(runtime().status,0);
 delete report.main.services.abilities;assert.notEqual(runtime().status,0);
 report.main.services.abilities=original;report.main.services.extra=original;assert.notEqual(runtime().status,0);
 console.log('COMPOSITION NEGATIVE PASS runtime changed script / removed provider / additional provider');
}finally{assert.equal(path.dirname(fixture),parent);fs.rmSync(fixture,{recursive:true,force:true});}
