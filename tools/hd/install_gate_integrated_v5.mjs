// Register only gate architecture and passage material; original walls stay intact.
import fs from 'node:fs';
const path='godot/chibi_remake/art/full/manifest.json';
let text=fs.readFileSync(path,'utf8');
const data=JSON.parse(text);
for(const id of [16,17]){
  const entry=data.atlases[id];
  entry.texture='res://art/full/buildings/017-atlas-v1.png';
  entry.frames=[[152,2,659,872],[1069,1,660,873]].map(region=>({region,draw:[id===16?0.1255722045898:22.1255722045898,0,65.7488555908203,87]}));
  const start=text.indexOf(`    "${id}": {`)+`    "${id}": `.length;
  const end=text.indexOf('\n    },',start)+6;
  text=text.slice(0,start)+JSON.stringify(entry,null,2).replaceAll('\n','\n    ')+text.slice(end);
}
// Offsets belonged to the old low platform, which is no longer drawn.
const offsetStart=text.indexOf('"gateWallOffsets": ');
if(offsetStart>=0){
  const valueStart=offsetStart+'"gateWallOffsets": '.length;
  let end=valueStart,depth=0;
  do{if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++;}while(depth>0);
  text=text.slice(0,valueStart)+'{}'+text.slice(end);
}
if(JSON.stringify(JSON.parse(text).terrain)!==JSON.stringify(data.terrain))throw new Error('Gate registration changed walls');
fs.writeFileSync(path,text);
console.log('GATE INTEGRATED V5: full-height masonry gateway, original wall definitions preserved.');
