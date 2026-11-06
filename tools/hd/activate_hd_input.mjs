// Bind painted cursor art and scalable edge arrows; no low-resolution runtime fallback.
import fs from 'node:fs';
const dir='godot/chibi_remake/art/full/ui/input';
if(!fs.existsSync(dir+'/cursor-hd-v1.png'))throw new Error('Restore the generated HD cursor master first.');
const cursor=JSON.parse(fs.readFileSync('research/cursor/data/cursor_states.json','utf8'));
cursor.runtimeTextures={A:'res://art/full/ui/input/cursor-hd-v1.png',B:'res://art/full/ui/input/cursor-edges-hd-v1.svg',C:'res://art/full/ui/input/cursor-hd-v1.png'};
cursor.sourceRows={A:[0,156,307,471,635,772,925,1088,1222,1384,1596],B:Array.from({length:9},(_,i)=>i*384),C:[0,156]};
cursor.artMode='painted-hd';
fs.writeFileSync('godot/chibi_remake/data/db/cursors.json',JSON.stringify(cursor,null,2)+'\n');
const diagonal='0,0 14,1 10,5 22,17 17,22 5,10 1,14';
const cardinal='10,0 21,10 15,10 15,23 8,23 8,10 1,10';
let svg='<svg xmlns="http://www.w3.org/2000/svg" width="384" height="3072" viewBox="0 0 24 192"><defs><linearGradient id="metal" x2="1" y2="1"><stop stop-color="#fffef0"/><stop offset=".42" stop-color="#fffef0"/><stop offset=".53" stop-color="#f0c963"/><stop offset="1" stop-color="#a87727"/></linearGradient></defs>';
for(let i=0;i<8;i++)svg+=`<g transform="translate(0 ${i*24})"><g transform="rotate(${Math.floor(i/2)*90} 11.5 11.5)"><polygon points="${i%2?cardinal:diagonal}" fill="url(#metal)" stroke="#342719" stroke-width=".65" stroke-linejoin="round"/></g></g>`;
fs.writeFileSync(dir+'/cursor-edges-hd-v1.svg',svg+'</svg>\n');
console.log('Activated HD cursor master and eight vector edge arrows.');
