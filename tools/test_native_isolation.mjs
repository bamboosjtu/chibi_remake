import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const sourceExe=path.resolve(option('--exe')),directory=path.resolve(option('--output','_work/native-isolation'));
fs.mkdirSync(directory,{recursive:true});const fixture=fs.mkdtempSync(path.join(directory,'game-')),source=path.dirname(sourceExe);
const entries=[path.basename(sourceExe),path.basename(sourceExe).replace(/\.exe$/i,'.pck'),...fs.readdirSync(source).filter(file=>/\.dll$/i.test(file)||file==='portable.txt')];
for(const relative of entries){const input=path.join(source,relative),output=path.join(fixture,relative);fs.mkdirSync(path.dirname(output),{recursive:true});try{fs.linkSync(input,output);}catch{fs.copyFileSync(input,output);}}
const username=(process.env.USERNAME||'player').replace(/[<>:"/\\|?*]/g,'_');const player=path.join(fixture,'userdata',username),canary=path.join(fixture,'canary');fs.mkdirSync(player,{recursive:true});fs.mkdirSync(canary);
const sentinels=[path.join(player,'save.json'),path.join(player,'slot-20.json'),path.join(canary,'save.json')];for(const file of sentinels)fs.writeFileSync(file,'player sentinel');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),before=sentinels.map(hash),results=[];
for(const [name,extra,code,marker] of [
 ['write',['--native-save=write'],0,'NATIVE SAVE ACCEPTANCE PASS write'],
 ['selftest',['--selftest'],0,'SELFTEST RESULT: PASS'],
 ['reject-dir',['--native-save=write','--save-test-dir='+canary],1,null],
 ['reject-id',['--native-save=write','--save-test-id=../player'],1,null]
]){
 const result=await runGodot({engine:path.join(fixture,path.basename(sourceExe)),directory,name:'native-isolation-'+name,timeout:120,args:['--headless','--resolution','1920x1080','--','--map=chibil1','--no-intro','--view',...extra],markers:marker?[marker]:[]});
 assert.equal(result.code,code,result.output);assert(!result.timedOut,result.output);assert(!result.missing.length,result.output);assert.doesNotMatch(result.output,/SCRIPT ERROR:|SELFTEST RESULT: FAIL/);
 assert.deepEqual(sentinels.map(hash),before,'Native test entry changed player or arbitrary directory files');
 const {output,...summary}=result;results.push({...summary,ok:true,observedExitCode:result.code,expectedExitCode:code,code:0});fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');console.log('PASS native-isolation-'+name);
}
console.log('NATIVE ISOLATION PASS exported write/selftest without ID / arbitrary directory and traversal rejection / player sentinels unchanged');
