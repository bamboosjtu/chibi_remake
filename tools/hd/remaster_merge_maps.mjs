import fs from 'node:fs';
const dir='godot/chibi_remake/art/full/maps';
const catalog=JSON.parse(fs.readFileSync('godot/chibi_remake/art/production/catalog.json'));
const filename=`${dir}/manifest.json`;
const manifest=JSON.parse(fs.readFileSync(filename));
for(const file of fs.readdirSync(dir).filter(x=>/^chibi.*\.json$/.test(x)))manifest.maps[file.slice(0,-5)]=JSON.parse(fs.readFileSync(`${dir}/${file}`));
for(const id of catalog.maps){
  const map=manifest.maps[id];
  if(!map||map.quality!=='pass')throw new Error(`Map not ready: ${id}`);
  for(const texture of map.terrainHD)if(!fs.existsSync('godot/chibi_remake/'+texture.replace('res://','')))throw new Error(`Missing texture: ${texture}`);
  const source=JSON.parse(fs.readFileSync(`_work/full-art-map-source/${id}.json`));
  if(map.sourceSha256!==source.sourceSha256)throw new Error(`Source changed: ${id}`);
}
fs.writeFileSync(filename,JSON.stringify(manifest,null,2)+'\n');
console.log(`Activated ${catalog.maps.length} HD maps; original MED source hashes verified.`);
