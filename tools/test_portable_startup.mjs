import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {runGodot,isEngineFailure} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const directory=path.resolve(option('--output','_work/portable-startup')),engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe'));
const results=[];
for(const [name,value]of Object.entries({traversal:'../escape',scheme:'res://data',drive:'C:',empty:'',network:'//server/share'})){
 const r=await runGodot({engine,directory,name,timeout:60,markers:['APP STARTUP FAILURE PASS','Invalid portable root'],
  args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_app_startup_failure.gd'),'--','--save-test-id=portable-'+crypto.randomUUID(),'--portable-root='+value]});
 if(name==='empty')r.missing=r.missing.filter(marker=>marker!=='Invalid portable root');
 r.ok=r.code===1&&!r.timedOut&&!isEngineFailure(r.output)&&r.missing.length===0;
 const {output,...summary}=r;results.push(summary);console.log(`${r.ok?'PASS':'FAIL'} portable-${name}`);
}
const r=await runGodot({engine,directory,name:'absolute',timeout:60,markers:['USER STORAGE PASS'],
 args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_user_storage.gd'),'--','--save-test-id=portable-'+crypto.randomUUID(),'--portable-root='+path.join(directory,'explicit-root')]});
const {output,...summary}=r;results.push(summary);
fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');
assert(results.every(row=>row.ok),'Portable startup regression failed: '+directory);
console.log('PORTABLE STARTUP PASS invalid roots refused before storage writes / explicit absolute root retained');
