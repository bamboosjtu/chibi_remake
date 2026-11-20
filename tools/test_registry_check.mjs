import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/registry-fixtures');fs.mkdirSync(parent,{recursive:true});const fixture=fs.mkdtempSync(parent+'/named-');
function copy(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||['art','assets','media','data','addons'].includes(e.name))continue;const r=path.join(rel,e.name);if(e.isDirectory())copy(path.join(dir,e.name),r);else if(e.name.endsWith('.gd')){fs.mkdirSync(path.dirname(path.join(fixture,r)),{recursive:true});fs.writeFileSync(path.join(fixture,r),fs.readFileSync(path.join(dir,e.name),'utf8').replaceAll('\r\n','\n'));}}}
const run=()=>spawnSync(process.execPath,['tools/registry_check.mjs','--root',fixture],{encoding:'utf8'});
try{copy('godot/chibi_remake');assert.equal(run().status,0);
 for(const [file,from,to] of [
  ['simulation/battle/unit_actions.gd','_dep_combat._fire_attack','_dep_combat.nonexistent'],
  ['simulation/state/battle_state.gd','var units:', 'var unregistered_units:'],
  ['menu.gd','preload("res://presentation/menu/controller.gd")','preload("res://missing.gd")'],
 ]) {
  const target=path.join(fixture,file), original=fs.readFileSync(target,'utf8');
  const changed=original.replace(from,to);
  assert.notEqual(original,changed);
  fs.writeFileSync(target,changed); assert.notEqual(run().status,0,file); fs.writeFileSync(target,original);
 }
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
