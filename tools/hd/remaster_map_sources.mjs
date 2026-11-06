import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
import {parseMed} from '../lib/medmap.mjs';import {parseGroundExp} from '../lib/terrain_bake.mjs';
const args=process.argv.slice(2),value=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const meds=value('--meds'),set=value('--set'),output=path.resolve(value('--output','source/terrain'));
if(!meds||!set)throw Error('Usage: node tools/hd/remaster_map_sources.mjs --meds <MED directory> --set <SET directory> [--output source/terrain]');
const index=JSON.parse(fs.readFileSync(path.join(output,'index.json')));
for(const id of index.maps){const bytes=fs.readFileSync(path.join(meds,id.toUpperCase()+'.MED')),m=parseMed(bytes);fs.writeFileSync(path.join(output,id+'.json'),JSON.stringify({id,rows:m.rows,cols:m.cols,width:44*m.rows+88,height:11*m.cols+160,layers:m.layers.map(layer=>layer.map(row=>Array.from(row))),sourceSha256:crypto.createHash('sha256').update(bytes).digest('hex')}));}
index.grounds=parseGroundExp(set);fs.writeFileSync(path.join(output,'index.json'),JSON.stringify(index));
console.log('Imported '+index.maps.length+' layouts; review changes, then refresh hashes with tools/terrain_sources.mjs --write');
