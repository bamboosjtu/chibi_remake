import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),value=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const source=path.resolve(value('--source','source/terrain'));
const cache=path.resolve(value('--cache','_work/terrain'));
const engine=path.resolve(value('--engine','Godot_v4.7.2-stable_win64.exe'));
const digest=buffer=>crypto.createHash('sha256').update(buffer).digest('hex');
const sourceManifest=JSON.parse(fs.readFileSync(path.join(source,'inputs.json'),'utf8'));
const missing=[];
for(const entry of sourceManifest.files){
 const file=path.resolve(source,entry.path);
 if(!file.startsWith(source+path.sep))throw Error('Unsafe source path '+entry.path);
 if(!fs.existsSync(file)||digest(fs.readFileSync(file))!==entry.sha256)missing.push(entry.path);
}
if(missing.length)throw Error('Missing or changed versioned terrain inputs:\n'+missing.join('\n'));
const index=JSON.parse(fs.readFileSync(path.join(source,'index.json')));
const bakerFiles=['tools/gd/bake_full_terrain.gd','tools/gd/build_terrain_lods.gd'];
const engineSha256=digest(fs.readFileSync(engine));
const common=digest(Buffer.concat([...sourceManifest.files.filter(f=>!/^chibi.*\.json$/.test(f.path)).map(f=>Buffer.from(f.path+f.sha256)),...bakerFiles.map(f=>fs.readFileSync(f)),Buffer.from(engineSha256+'/scale4/q95-q78/LOD4-2-1')]));
const keys=new Map(index.maps.map(id=>[id,digest(Buffer.from(common+digest(fs.readFileSync(path.join(source,id+'.json')))))]));
if(args.includes('--keys-only')){console.log(JSON.stringify(Object.fromEntries(keys)));process.exit(0);}
function validEntry(id){try{const entry=path.join(cache,'maps',keys.get(id)),record=JSON.parse(fs.readFileSync(path.join(entry,'complete.json')));return record.key===keys.get(id)&&record.files.every(f=>digest(fs.readFileSync(path.join(entry,'runtime',f.name)))===f.sha256);}catch{return false;}}
const pending=index.maps.filter(id=>!validEntry(id));
fs.mkdirSync(cache,{recursive:true});
const lock=path.join(cache,'build.lock');let fd;
try{fd=fs.openSync(lock,'wx');fs.writeFileSync(fd,String(process.pid));}
catch{
 const owner=Number(fs.readFileSync(lock,'utf8'));
 let active=true;try{process.kill(owner,0);}catch(error){if(error.code==='ESRCH')active=false;}
 if(active)throw Error('Another terrain build is active; lock: '+lock);
 fs.unlinkSync(lock);fd=fs.openSync(lock,'wx');fs.writeFileSync(fd,String(process.pid));
}
const job=fs.mkdtempSync(path.join(cache,'job-'));
async function run(name,script,extra){
 const result=await runGodot({engine,directory:job,name,timeout:7200,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve(script),'--',...extra]});
 if(!result.ok)throw Error(name+' failed: '+result.log);
}
try{
 if(pending.length){
  await run('bake','tools/gd/bake_full_terrain.gd',['--source-root='+source,'--output='+path.join(job,'maps'),'--map-list='+pending.join(',')]);
  const records={maps:{}};
  for(const id of pending){const data=JSON.parse(fs.readFileSync(path.join(job,'maps',id+'.json')));data.terrainHD=[0,1,2,3].map(q=>path.join(job,'maps',id+`_q${q}.png`));records.maps[id]=data;}
  fs.writeFileSync(path.join(job,'maps.json'),JSON.stringify(records));
  await run('lods','tools/gd/build_terrain_lods.gd',['--manifest='+path.join(job,'maps.json'),'--output='+path.join(job,'runtime')]);
  if(args.includes('--fail-before-publish'))throw Error('Injected interruption before cache publication');
  for(const id of pending){
   const destination=path.join(cache,'maps',keys.get(id));fs.mkdirSync(path.dirname(destination),{recursive:true});
   const temporary=path.join(job,'entry-'+id);fs.mkdirSync(temporary);
   fs.renameSync(path.join(job,'runtime/art/full/terrain_chunks',id),path.join(temporary,'runtime'));
   fs.mkdirSync(path.join(temporary,'maps'));for(const q of [0,1,2,3])fs.renameSync(path.join(job,'maps',id+`_q${q}.png`),path.join(temporary,'maps',id+`_q${q}.png`));
   const files=fs.readdirSync(path.join(temporary,'runtime')).map(name=>({name,sha256:digest(fs.readFileSync(path.join(temporary,'runtime',name)))}));
   fs.writeFileSync(path.join(temporary,'complete.json'),JSON.stringify({schemaVersion:1,map:id,key:keys.get(id),files}));
   if(fs.existsSync(destination))fs.renameSync(destination,destination+'.invalid-'+crypto.randomUUID());
   fs.renameSync(temporary,destination);
  }
 }
 const current=path.join(cache,'current/art/full/terrain_chunks');fs.mkdirSync(current,{recursive:true});
 for(const id of index.maps){
  const entry=path.join(cache,'maps',keys.get(id)),record=JSON.parse(fs.readFileSync(path.join(entry,'complete.json')));
  const output=path.join(current,id);fs.mkdirSync(output,{recursive:true});
  for(const file of record.files){const input=path.join(entry,'runtime',file.name),target=path.join(output,file.name);if(digest(fs.readFileSync(input))!==file.sha256)throw Error('Corrupt terrain cache: '+input);if(fs.existsSync(target))fs.unlinkSync(target);try{fs.linkSync(input,target);}catch{fs.copyFileSync(input,target);}}
 }
 fs.writeFileSync(path.join(cache,'current/build.json'),JSON.stringify({schemaVersion:1,engineSha256,sourceManifestSha256:digest(fs.readFileSync(path.join(source,'inputs.json'))),maps:Object.fromEntries(keys)},null,2));
 if(args.includes('--dev')){
  const targetRoot=path.resolve('godot/chibi_remake/art/full/terrain_chunks');
  for(const id of index.maps){const input=path.join(current,id),output=path.join(targetRoot,id);fs.mkdirSync(output,{recursive:true});for(const file of fs.readdirSync(input)){const target=path.join(output,file);if(fs.existsSync(target))fs.unlinkSync(target);try{fs.linkSync(path.join(input,file),target);}catch{fs.copyFileSync(path.join(input,file),target);}}}
 }
 console.log(`TERRAIN BUILD PASS ${index.maps.length} maps / ${pending.length} rebuilt / ${index.maps.length-pending.length} cache hits`);
}finally{fs.closeSync(fd);fs.unlinkSync(lock);}
