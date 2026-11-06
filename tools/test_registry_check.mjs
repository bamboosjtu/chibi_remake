import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/registry-fixtures');fs.mkdirSync(parent,{recursive:true});const fixture=fs.mkdtempSync(parent+'/named-');
function copy(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||['art','assets','media','data','addons'].includes(e.name))continue;const r=path.join(rel,e.name);if(e.isDirectory())copy(path.join(dir,e.name),r);else if(e.name.endsWith('.gd')){fs.mkdirSync(path.dirname(path.join(fixture,r)),{recursive:true});fs.copyFileSync(path.join(dir,e.name),path.join(fixture,r));}}}
const run=()=>spawnSync(process.execPath,['tools/registry_check.mjs','--root',fixture],{encoding:'utf8'});
try{copy('godot/chibi_remake');assert.equal(run().status,0);
 for(const [file,change] of [
  ['simulation/ports/abilities_dependencies.gd',s=>s.replace('"_kill"','"__missing_method"')],
  ['simulation/ports/ai_access.gd',s=>s+'\nvar _fn_legacy: Callable\n'],
  ['presentation/battle/battle_access.gd',s=>s.replace('_commands.get_ref().handle_cheat_input','_commands.get_ref().__missing_command')]
 ]){const p=path.join(fixture,file),old=fs.readFileSync(p,'utf8');fs.writeFileSync(p,change(old));assert.notEqual(run().status,0,file);fs.writeFileSync(p,old);}
 console.log('REGISTRY NEGATIVE PASS missing provider method / retired dispatch / missing presentation command');
}finally{assert.equal(path.dirname(fixture),parent);fs.rmSync(fixture,{recursive:true,force:true});}
