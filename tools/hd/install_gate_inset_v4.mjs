// Register the two facade states only. Terrain definitions are never edited.
import fs from 'node:fs';
const path='godot/chibi_remake/art/full/manifest.json';
let text=fs.readFileSync(path,'utf8');
const manifest=JSON.parse(text);
const before=JSON.stringify(manifest.terrain);
for(const id of [16,17]){
  const entry=manifest.atlases[id];
  entry.texture='res://art/full/buildings/gate-inset-v4.png';
  entry.frames=[[94,36,837,680],[1118,36,837,680]].map(region=>({region,draw:[0,0,43.15,27.95]}));
  const start=text.indexOf(`    "${id}": {`)+`    "${id}": `.length;
  const end=text.indexOf('\n    },',start)+6;
  text=text.slice(0,start)+JSON.stringify(entry,null,2).replaceAll('\n','\n    ')+text.slice(end);
}
if(JSON.stringify(manifest.terrain)!==before)throw new Error('Gate installation changed terrain');
if(JSON.stringify(JSON.parse(text))!==JSON.stringify(manifest))throw new Error('Gate patch differs from intended manifest');
fs.writeFileSync(path,text);
console.log('GATE INSET V4: both diagonal facade states registered; terrain unchanged.');
