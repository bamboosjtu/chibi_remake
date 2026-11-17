import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {runGodot, isEngineFailure} from './lib/godot_process.mjs';

const args=process.argv.slice(2),option=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe'));
const directory=path.resolve(option('--output','_work/rule-startup'));
fs.mkdirSync(directory,{recursive:true});
const project=fs.mkdtempSync(path.join(directory,'project-'));
const source=path.resolve('godot/chibi_remake');
const files=[...new Set(execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z','--','godot/chibi_remake'],{maxBuffer:64*1024*1024}).toString().split('\0').filter(file=>file&&fs.existsSync(file)))];
for(const file of files){
 const relative=path.relative(source,path.resolve(file)),target=path.join(project,relative);
 fs.mkdirSync(path.dirname(target),{recursive:true});
 // Link immutable binaries only. Every fault changes private JSON/script copies.
 if(/\.(png|svg|jpe?g|ico|otf|ttf|wav|ogg|avi|dll|bin)$/i.test(file)){try{fs.linkSync(file,target);}catch{fs.copyFileSync(file,target);}}
 else fs.copyFileSync(file,target);
}
const names=['unit_definitions','production_units','buildings','unit_tuning','officers','officer_progression','command_variants','scenario_rules','native_math'];
const original=Object.fromEntries(names.map(name=>[name,fs.readFileSync(path.join(source,'data/db',name+'.json'))]));
const nativeFile='simulation/native/bin/ChibiSimulationMath.dll';
const nativeAvailable=process.platform==='win32'&&fs.existsSync(path.join(source,nativeFile));
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const nativeDigest=nativeAvailable?digest(fs.readFileSync(path.join(source,nativeFile))):null;
const write=(name,value)=>fs.writeFileSync(path.join(project,'data/db',name+'.json'),value);
const restore=()=>{
 for(const [name,bytes] of Object.entries(original))write(name,bytes);
 if(nativeAvailable){
  const target=path.join(project,nativeFile);
  if(fs.existsSync(target))fs.unlinkSync(target);
  try{fs.linkSync(path.join(source,nativeFile),target);}catch{fs.copyFileSync(path.join(source,nativeFile),target);}
 }
};
const cases=[
 {name:'scene-startup',scene:'res://main.tscn',markers:['ARCH-013: view=false'],args:['--noview','--map=chibic1','--smoketest']},
 {name:'runtime-no-files',script:'test_rule_catalog',markers:['RULE CATALOG PASS'],args:['--rules-delete-fixture='+project]},
 {name:'missing',change:()=>fs.unlinkSync(path.join(project,'data/db/unit_tuning.json')),errors:['unit_tuning.json: cannot read']},
 {name:'parse',change:()=>write('command_variants','{broken'),errors:['command_variants.json: JSON line']},
 {name:'all-invalid',change:()=>{for(const name of names)write(name,'{}');},errors:names.map(name=>name+'.json: invalid required gameplay fields')},
 {name:'aggregate',change:()=>{fs.unlinkSync(path.join(project,'data/db/unit_tuning.json'));write('command_variants','{broken');write('officers','{}');},errors:['unit_tuning.json: cannot read','command_variants.json: JSON line','officers.json: invalid required gameplay fields']},
 {name:'scene-refuses-invalid',scene:'res://main.tscn',change:()=>write('unit_tuning','{}'),
  markers:['Rule startup failed:','unit_tuning.json: invalid required gameplay fields'],errors:['Rule startup failed:']},
];
if(nativeAvailable)cases.push({name:'script-fallback',script:'test_rule_catalog',markers:['RULE CATALOG PASS'],
 args:['--rules-expect-script'],change:()=>fs.unlinkSync(path.join(project,nativeFile))},{
 name:'native-load-failure',change:()=>{
  // Break the private fixture's hardlink before writing corrupt bytes.
  const target=path.join(project,nativeFile);fs.unlinkSync(target);fs.writeFileSync(target,'invalid extension bytes');
 },errors:['Simulation math backend failed to load'],args:['--rules-native-failure']},{
 name:'native-mismatch',change:()=>write('native_math',JSON.stringify({algorithm:'dictionary-math-v1',sourceSignature:'0'.repeat(64)})),
 errors:['Simulation math source/binary mismatch'],args:['--rules-native-failure']});
const results=[];
for(const test of cases){
 restore();test.change?.();
 const failure=!!test.errors;
 const markers=test.markers??['RULE STARTUP FAILURE PASS',...test.errors];
 const result=await runGodot({engine,directory,name:test.name,timeout:120,markers,
  args:['--headless','--path',project,...(test.scene?[test.scene]:['--script',path.resolve('tools/gd',test.script??'test_rule_startup_failure')+'.gd']),'--','--no-intro','--save-test-id=rule-'+crypto.randomUUID(),...(args.includes('--cpu-only')?['--noview']:[]),...(test.args??[])]});
 // Startup fault probes intentionally exit 1, without a GDScript/assertion error.
 if(failure)result.ok=result.code===1&&!result.timedOut&&!isEngineFailure(result.output)&&result.missing.length===0;
 const {output,...summary}=result;results.push(summary);
 fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');
 console.log(`${result.ok?'PASS':'FAIL'} ${test.name} (${result.seconds.toFixed(1)}s) ${result.log}`);
}
restore();
for(const [name,bytes] of Object.entries(original))assert.equal(digest(fs.readFileSync(path.join(source,'data/db',name+'.json'))),digest(bytes),'Source rules modified: '+name);
if(nativeAvailable)assert.equal(digest(fs.readFileSync(path.join(source,nativeFile))),nativeDigest,'Source backend modified');
assert(results.every(result=>result.ok),'Rule startup fixture failed; inspect '+directory);
console.log('RULE STARTUP PASS isolated startup faults / aggregate diagnostics / no partial publication / files removed after startup / original catalogs unchanged');
