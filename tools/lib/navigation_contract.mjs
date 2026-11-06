import fs from 'node:fs';
import {parseMed} from './medmap.mjs';
for(const filename of fs.readdirSync('godot/chibi_remake/data').filter(x=>x.startsWith('chibi')&&x.endsWith('.json'))){
  const path='godot/chibi_remake/data/'+filename;
  const value=JSON.parse(fs.readFileSync(path));
  const map=parseMed(fs.readFileSync('_work/iso/MEDS/'+filename.replace('.json','.MED').toUpperCase()));
  value.terrainWalkable=[];
  for(let a=0;a<map.rows;a++)for(let b=0;b<map.cols;b++){
    const t=map.layers[0][a][b],hi=t>>12&15;
    value.terrainWalkable.push(t!==65535&&[15,8,9].includes(hi)&&map.layers[1][a][b]===65535&&map.layers[2][a][b]===65535?1:0);
  }
  value.navigation={schemaVersion:1,topology:'staggered-diamond-four-edges',occupancy:'dynamic-footprints'};
  fs.writeFileSync(path,JSON.stringify(value));
}
const exporter='tools/godot_export.mjs';
let source=fs.readFileSync(exporter,'utf8');
if(!source.includes('const terrainWalk ='))source=source.replace('// static buildings block their cell too','const terrainWalk = walk.slice();\n// static buildings block their cell too').replace('walkable: walk,','walkable: walk,\n  terrainWalkable: terrainWalk,\n  navigation: { schemaVersion: 1, topology: "staggered-diamond-four-edges", occupancy: "dynamic-footprints" },');
fs.writeFileSync(exporter,source);
console.log('34 terrain-only navigation grids; exporter updated.');
