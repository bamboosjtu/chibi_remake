// Installs the selected image_gen atlas without resampling its alpha or pixels.
// The battle gate_module samples only the aperture, omitting all generated
// masonry. Terrain retains its original walls and is clipped at the aperture.
import fs from 'node:fs';
const file='godot/chibi_remake/art/full/manifest.json';
let text=fs.readFileSync(file,'utf8');
const manifest=JSON.parse(text);
const atlas='res://art/full/buildings/gate-wall-v3.png';
const definitions={
  17:{draw:[-5,-5,110,110*541/602],regions:[[24,79,602,541],[651,79,602,541]]},
  16:{draw:[-19,-5,110,110*533/603],regions:[[1,687,603,533],[628,687,603,533]]},
};
for(const [id,layout] of Object.entries(definitions)){
 const entry=manifest.atlases[id];entry.texture=atlas;
 entry.frames=layout.regions.map(region=>({draw:layout.draw,region}));
 const start=text.indexOf(`    "${id}": {`)+`    "${id}": `.length;
 const end=text.indexOf('\n    },',start)+6;
 text=text.slice(0,start)+JSON.stringify(entry,null,2).replaceAll('\n','\n    ')+text.slice(end);
}
fs.writeFileSync(file,text);
console.log('Installed reference-v3 masonry gate atlas for both diagonals and states.');
