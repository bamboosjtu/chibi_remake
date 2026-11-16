import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe'));
const directory=path.resolve(option('--output','_work/missing-presentation'));
fs.mkdirSync(directory,{recursive:true});
const project=fs.mkdtempSync(path.join(directory,'project-'));
const source=path.resolve('godot/chibi_remake');
const files=[...new Set(execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z','--','godot/chibi_remake'],{maxBuffer:64*1024*1024}).toString().split('\0').filter(file=>file&&fs.existsSync(file)))];
for(const file of files){
 const relative=path.relative(source,path.resolve(file)),target=path.join(project,relative);
 fs.mkdirSync(path.dirname(target),{recursive:true});
 // Only immutable binary assets are linked. Script/JSON/import metadata are private copies.
 if(/\.(png|svg|jpe?g|ico|otf|ttf|wav|ogg|avi|dll|bin)$/i.test(file)){try{fs.linkSync(file,target);}catch{fs.copyFileSync(file,target);}}
 else fs.copyFileSync(file,target);
}
const cases={panel:'art/full/ui/hud_right-redraw-v2.png',controls:'art/full/ui/left-controls-redraw-v4.png',
 banner:'art/full/ui/hud_banner-redraw-v2.png',icons:'art/full/ui/resource-icons-redraw-v3.png',
 'minimap-missing':'data/db/minimap_terrain.json','minimap-invalid':'data/db/minimap_terrain.json',
 'minimap-entry':'data/db/minimap_terrain.json','minimap-png':'data/db/minimap_terrain.json','terrain-budget':null};
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const originals=Object.fromEntries([...new Set(Object.values(cases).filter(Boolean))].map(file=>[file,sha(path.join(source,file))]));
const results=[];
for(const [mode,relative] of Object.entries(cases)){
 const target=relative?path.resolve(project,relative):null;
 if(target){
  assert(target.startsWith(project+path.sep));
  fs.unlinkSync(target);
  if(mode==='minimap-invalid')fs.writeFileSync(target,'{bad JSON');
  if(mode==='minimap-entry')fs.writeFileSync(target,JSON.stringify({maps:{}}));
  if(mode==='minimap-png')fs.writeFileSync(target,JSON.stringify({maps:{chibil1:{png:Buffer.from('invalid PNG').toString('base64')}}}));
 }
 try{
  const result=await runGodot({engine,directory,name:mode,timeout:120,
   args:['--headless','--path',project,'--script',path.resolve('tools/gd/test_missing_presentation.gd'),'--',
    '--no-intro','--save-test-id=presentation-'+crypto.randomUUID(),'--presentation-case='+mode],
   markers:['PRESENTATION FAILURE PASS '+mode]});
  const {output,...summary}=result;results.push(summary);
  fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');
  console.log(`${result.ok?'PASS':'FAIL'} ${mode} (${result.seconds.toFixed(1)}s) ${result.log}`);
 }finally{
  if(target){if(fs.existsSync(target))fs.unlinkSync(target);fs.copyFileSync(path.join(source,relative),target);}
 }
}
for(const [relative,hash] of Object.entries(originals))assert.equal(sha(path.join(source,relative)),hash,'Source asset modified: '+relative);
assert(results.every(result=>result.ok),'Presentation failure fixture failed; inspect '+directory);
console.log('MISSING PRESENTATION PASS isolated project / four missing UI sources / four catalog failures / terrain budget and pending-job recovery / original assets unchanged');
