import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const engineArg=process.argv.indexOf('--engine'),engine=path.resolve(engineArg<0?'Godot_v4.7.2-stable_win64.exe':process.argv[engineArg+1]);
const parent=path.resolve('_work/terrain-pipeline-tests');fs.mkdirSync(parent,{recursive:true});const fixture=fs.mkdtempSync(parent+'/case-'),source=path.join(fixture,'source'),cache=path.join(fixture,'cache');
fs.mkdirSync(path.join(source,'paint'),{recursive:true});fs.mkdirSync(path.join(source,'masks'),{recursive:true});
const read=file=>JSON.parse(fs.readFileSync('source/terrain/'+file));const asset=read('catalog.json').assets[0];
fs.copyFileSync(path.join('source/terrain',asset.paint),path.join(source,asset.paint));fs.copyFileSync('source/terrain/masks/terrain-00-source.png',path.join(source,'masks/terrain-00-source.png'));
fs.writeFileSync(path.join(source,'catalog.json'),JSON.stringify({assets:[asset]}));fs.writeFileSync(path.join(source,'mapping.json'),JSON.stringify({terrain:{'0':read('mapping.json').terrain['0']}}));
const index=read('index.json');index.maps=['chibil1'];fs.writeFileSync(path.join(source,'index.json'),JSON.stringify(index));
const layout={id:'chibil1',rows:2,cols:2,width:176,height:182,layers:[[[0,0],[0,0]],[[65535,65535],[65535,65535]],[[65535,65535],[65535,65535]]],sourceSha256:'fixture'};
const writeLayout=()=>fs.writeFileSync(path.join(source,'chibil1.json'),JSON.stringify(layout));writeLayout();
const refresh=()=>{const r=spawnSync(process.execPath,['tools/terrain_sources.mjs','--source',source,'--write'],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);};refresh();
function build(extra=[],expected=0){const r=spawnSync(process.execPath,['tools/build_terrain.mjs','--source',source,'--cache',cache,'--engine',engine,...extra],{encoding:'utf8',timeout:180000});fs.appendFileSync(path.join(fixture,'test.log'),r.stdout+r.stderr);assert.equal(r.status,expected,r.stdout+r.stderr);return r.stdout;}
const fakeEngine=path.join(fixture,'same-version-engine');
function identity(bytes){fs.writeFileSync(fakeEngine,bytes);const r=spawnSync(process.execPath,['tools/build_terrain.mjs','--source',source,'--engine',fakeEngine,'--keys-only'],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);return JSON.parse(r.stdout);}
assert.notDeepEqual(identity('engine build A'),identity('engine build B'),'Same version with different engine bytes must invalidate the cache');
build(['--fail-before-publish'],1);
assert(!fs.existsSync(path.join(cache,'maps')),'Interrupted generation must not publish completion');
assert.match(build(),/1 rebuilt/);assert.match(build(),/0 rebuilt/);
layout.revision=1;writeLayout();refresh();assert.match(build(),/1 rebuilt/);
const pointer=JSON.parse(fs.readFileSync(path.join(cache,'current/build.json'))),entry=path.join(cache,'maps',pointer.maps.chibil1,'runtime');
const bin=fs.readdirSync(entry).find(name=>name.endsWith('.bin'));fs.writeFileSync(path.join(entry,bin),'corrupt');assert.match(build(),/1 rebuilt/);
fs.writeFileSync(path.join(cache,'build.lock'),'2147483000');assert.match(build(),/0 rebuilt/);
fs.writeFileSync(path.join(cache,'build.lock'),String(process.pid));build([],1);fs.unlinkSync(path.join(cache,'build.lock'));
fs.unlinkSync(path.join(source,'masks/terrain-00-source.png'));build([],1);
console.log('TERRAIN PIPELINE PASS cold / cache hit / one-map invalidation / corruption rebuild / interrupted publication / stale and active lock / missing input rejection: '+fixture);
