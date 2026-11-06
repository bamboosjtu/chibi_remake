import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const generated=option('--generated','_work/terrain/current');
const old=option('--original','godot/chibi_remake');
const cache=option('--transport-cache','_work/build/terrain-cache/jpeg-q78-v1');
const rows=new Map(fs.readFileSync(option('--reference-snapshot','_work/remediation/before/runtime_assets.sha256'),'utf8').trim().split(/\r?\n/).map(line=>{const [sha,,file]=line.split('\t');return [file,sha];}));
const digest=buffer=>crypto.createHash('sha256').update(buffer).digest('hex');let files=0,equal=0,missing=0;
const hashes=new Map(),differences=[];
for(const id of JSON.parse(fs.readFileSync('source/terrain/index.json')).maps){
 const relative='art/full/terrain_chunks/'+id;
 const before=JSON.parse(fs.readFileSync(path.join(old,relative,'manifest.json'))),after=JSON.parse(fs.readFileSync(path.join(generated,relative,'manifest.json')));
 assert.equal(after.worldWidth,before.worldWidth,id);assert.equal(after.worldHeight,before.worldHeight,id);assert.equal(after.chunks.length,before.chunks.length,id);
 before.chunks.forEach((chunk,index)=>{
  assert.deepEqual(after.chunks[index].rect,chunk.rect,id+' rect '+index);
  for(const [lod,entry] of Object.entries(chunk.lods)){
   files++;const sourceSha=rows.get(entry.texture.replace(/^res:\/\//,''));const reference=path.join(cache,sourceSha+'.bin');
   const actual=path.join(generated,after.chunks[index].lods[lod].texture.replace(/^res:\/\//,''));
   if(!fs.existsSync(reference)){missing++;continue;}
   if(!hashes.has(reference))hashes.set(reference,digest(fs.readFileSync(reference)));
   if(hashes.get(reference)===digest(fs.readFileSync(actual)))equal++;else if(differences.length<100)differences.push({id,index,lod,reference,actual});
  }
 });
}
const result={maps:34,files,identical:equal,missingReferences:missing,differenceSamples:differences};
fs.mkdirSync('_work/remediation',{recursive:true});fs.writeFileSync('_work/remediation/terrain-comparison.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({...result,differenceSamples:differences.slice(0,3)}));if(equal!==files)process.exitCode=1;
