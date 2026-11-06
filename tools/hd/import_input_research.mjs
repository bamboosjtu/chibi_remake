// Activate the supplied research assets without running new reverse engineering.
import fs from 'node:fs';
import {readFrames,extractFrame,readPal} from '../lib/lwc2png.mjs';
import {writeRgbaPng} from '../lib/lwc_sheet.mjs';
const out='godot/chibi_remake/art/full/ui/input';
fs.mkdirSync(out,{recursive:true});
for(const [name,source] of Object.entries({
  'cursor-a.png':'mouse_frame0_216x350.png',
  'cursor-b.png':'mouse_frame1_24x192.png',
  'cursor-c.png':'mouse_banner.png',
}))fs.copyFileSync('research/cursor/assets/'+source,out+'/'+name);
const cursor=JSON.parse(fs.readFileSync('research/cursor/data/cursor_states.json','utf8'));
cursor.runtimeTextures={A:'res://art/full/ui/input/cursor-a.png',B:'res://art/full/ui/input/cursor-b.png',C:'res://art/full/ui/input/cursor-c.png'};
cursor.sourceScale={A:1,B:1,C:4};
// Preserve the project HD rendering binding when refreshing research metadata.
const currentCursor=JSON.parse(fs.readFileSync('godot/chibi_remake/data/db/cursors.json','utf8'));
if(currentCursor.artMode==='painted-hd'){
  cursor.runtimeTextures=currentCursor.runtimeTextures;cursor.sourceRows=currentCursor.sourceRows;cursor.artMode=currentCursor.artMode;delete cursor.sourceScale;
}
fs.writeFileSync('godot/chibi_remake/data/db/cursors.json',JSON.stringify(cursor,null,2)+'\n');
const commands=JSON.parse(fs.readFileSync('research/commands/data/commands.json','utf8'));
commands.runtimeActions=Object.fromEntries([
  [16130,'move'],[16131,'attack'],[16132,'watch'],[16133,'formation'],[16134,'rest'],[16135,'jimou'],
  [16136,'disband'],[16137,'duel'],[16138,'transport'],[16139,'build'],[16140,'build'],[16141,'repair'],
  [16142,'board'],[16143,'unload'],[16144,'form'],[16145,'join'],[16146,'return'],
]);
fs.writeFileSync('godot/chibi_remake/data/db/commands.json',JSON.stringify(commands,null,2)+'\n');
const frames=readFrames('_work/iso/BMP/BMP.LWC','_work/iso/BMP/BMP.IDX');
const palette=readPal('_work/iso/RES/SCORE.PAL');
const rows=JSON.parse(fs.readFileSync('research/commands/data/registry.json','utf8'));
for(const id of new Set(rows.map(e=>e.frame))){
  const f=frames[id],indices=extractFrame(f),rgba=Buffer.alloc(f.width*f.height*4);
  for(let i=0;i<indices.length;i++){
    const c=palette[indices[i]];rgba[i*4]=c[0];rgba[i*4+1]=c[1];rgba[i*4+2]=c[2];rgba[i*4+3]=indices[i]===0?0:255;
  }
  writeRgbaPng(`${out}/command-${String(id).padStart(3,'0')}.png`,f.width,f.height,rgba);
}
console.log('Imported',new Set(rows.map(e=>e.frame)).size,'registered command strips.');
