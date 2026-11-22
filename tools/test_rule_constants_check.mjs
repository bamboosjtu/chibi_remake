import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {sourceViolations,valueHash,documentation} from './lib/rule_constants.mjs';
const read=name=>JSON.parse(fs.readFileSync('godot/chibi_remake/data/db/'+name+'.json','utf8'));
const roles=read('unit_roles');
for(const bad of ['const HERO_TYPES=[29,31,33,35,0x34]','return int(u.unit) not in [52,49,48,47,46]','return _army_count(int(owner)) + reserved >= 200','return _army_count(owner)>=0xC8','return _army_count(owner)>=201','return _commander_count(owner)>=20','const TECH_TABLE = Other.TABLE'])assert(sourceViolations(bad,roles).length,bad);
for(const good of ['# const HERO_TYPES=[29,31,33,35,52]','const NOTE="_army_count(owner) >= 200"','return _army_count(owner)>=Balance.army_cap()','return _army_count(owner)>0','const CARRY_CAPACITY=200'])assert.deepEqual(sourceViolations(good,roles),[]);
assert.equal(valueHash({b:2,a:[1]}),valueHash({a:[1],b:2}));
const original=read('tech'),changed=structuredClone(original);changed.rows[0].v[0]+=1;
assert.notEqual(valueHash(original),valueHash(changed));
assert.notEqual(documentation(original,roles,read('balance')).costs,documentation(changed,roles,read('balance')).costs);
const parent=path.resolve('_work/constants-gate-fixtures');fs.mkdirSync(parent,{recursive:true});
const root=fs.mkdtempSync(path.join(parent,'case-'));
try{
 fs.mkdirSync(path.join(root,'data/db'),{recursive:true});
 for(const name of ['tech','unit_roles','balance'])fs.copyFileSync('godot/chibi_remake/data/db/'+name+'.json',path.join(root,'data/db',name+'.json'));
 const doc=path.join(root,'spec.md'),cpp=path.join(root,'native.cpp'),probe=path.join(root,'probe.gd');
 fs.copyFileSync('docs/40-economy/03-production-tech.md',doc);fs.writeFileSync(cpp,'// Backend receives the transport ID at startup.');
 const run=(extra=[])=>spawnSync(process.execPath,['tools/rule_constants_check.mjs','--root',root,'--docs',doc,'--native-source',cpp,...extra],{encoding:'utf8'});
 fs.writeFileSync(probe,'extends RefCounted\n');assert.equal(run().status,0);
 for(const source of ['const NAVAL=[46,47,48,49,52]','func test(owner):\n\treturn _army_count(owner)>=200']){
  fs.writeFileSync(probe,'extends RefCounted\n'+source+'\n');assert.notEqual(run().status,0);
 }
 fs.writeFileSync(probe,'extends RefCounted\n');
 fs.writeFileSync(cpp,'if (integer(u, k.unit, -1) == 47) return false;');assert.notEqual(run().status,0);
 fs.writeFileSync(cpp,'// Startup configuration only.');
 fs.writeFileSync(doc,fs.readFileSync(doc,'utf8').replace('<!-- RULE-costs:BEGIN -->','<!-- RULE-costs:BEGIN -->\nstale'));
 assert.notEqual(run().status,0);assert.equal(run(['--write']).status,0);assert.equal(run().status,0);
 fs.writeFileSync(path.join(root,'data/db/tech.json'),JSON.stringify(changed));assert.notEqual(run().status,0);
}finally{assert.equal(path.dirname(root),parent);fs.rmSync(root,{recursive:true,force:true});}
console.log('RULE CONSTANTS NEGATIVE PASS literal roles and caps / comments and strings / semantic values / stale documentation / native guard / actual CLI exit status');
