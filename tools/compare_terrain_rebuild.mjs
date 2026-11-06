import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const digest=buffer=>crypto.createHash('sha256').update(buffer).digest('hex');
const reference=option('--reference','tools/inputs/terrain_equivalence.sha256');
const metadata=JSON.parse(fs.readFileSync(reference+'.json','utf8'));
const bytes=fs.readFileSync(reference);
assert.equal(digest(bytes),metadata.snapshotSha256,'Terrain reference snapshot changed');
const sources=JSON.parse(fs.readFileSync('source/terrain/inputs.json','utf8'));
assert.equal(digest(JSON.stringify(sources.files)),metadata.sourceInputsSha256,'Terrain reference source inputs changed');
const maps=JSON.parse(fs.readFileSync('source/terrain/index.json','utf8')).maps;
assert.deepEqual(Object.keys(metadata.maps).sort(),[...maps].sort(),'Terrain reference must cover all maps');
const rows=bytes.toString('utf8').trim().split(/\r?\n/).map(line=>line.split('\t'));
const paths=new Set();
for(const [sha,file] of rows){
 assert.match(sha,/^[a-f0-9]{64}$/);assert.match(file,/^art\/full\/terrain_chunks\/chibi[a-z0-9]+\/[\w]+\.bin$/);
 assert(!paths.has(file),'Duplicate terrain reference: '+file);paths.add(file);
 assert(maps.includes(file.split('/')[3]),'Undeclared terrain map: '+file);
}
assert.equal(rows.length,metadata.files);
for(const id of maps)assert.equal(rows.filter(row=>row[1].split('/')[3]===id).length,metadata.maps[id].chunks*3,id+' LOD count');
if(args.includes('--declarations')){
 console.log('TERRAIN EQUIVALENCE DECLARATIONS PASS '+maps.length+' maps / '+rows.length+' historical transport hashes');
 process.exit(0);
}
const generated=option('--generated','_work/terrain/current');
let equal=0;
for(const [sha,file] of rows){assert.equal(digest(fs.readFileSync(path.join(generated,file))),sha,'Terrain differs from historical transport: '+file);equal++;}
for(const id of maps){
 const manifest=JSON.parse(fs.readFileSync(path.join(generated,'art/full/terrain_chunks',id,'manifest.json')));
 const geometry={width:manifest.worldWidth,height:manifest.worldHeight,chunks:manifest.chunks.map(c=>({rect:c.rect,lods:Object.keys(c.lods).sort()}))};
 assert.equal(digest(JSON.stringify(geometry)),metadata.maps[id].geometrySha256,id+' geometry differs');
}
console.log('TERRAIN EQUIVALENCE PASS '+maps.length+' maps / '+equal+' identical historical chunks / geometry and LODs');
