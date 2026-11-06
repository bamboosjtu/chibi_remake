// Production runtime coverage, separate from the archival source-bank catalogue.
import fs from 'node:fs';
import crypto from 'node:crypto';
const project='godot/chibi_remake',dir='godot/chibi_remake/art/production';
const manifest=JSON.parse(fs.readFileSync(project+'/art/full/manifest.json'));
const catalog=JSON.parse(fs.readFileSync(dir+'/catalog.json'));
const failures=[],textures=new Set();
for(const file of fs.readdirSync(project+'/data').filter(x=>/^chibi.*\.json$/.test(x))){
  const level=JSON.parse(fs.readFileSync(project+'/data/'+file));
  if(level.artMode!=='hd-catalog')failures.push('Native art bindings remain: '+file);
  // Rendering resolves live atlases by unit ID. Old level sheet labels may
  // name a retired atlas (notably gates) and are not additional build inputs.
  for(const ob of level.objects)texture(manifest.atlases[String(ob.unit)]?.texture);
  for(const id of Object.keys(level.units))texture(manifest.atlases[id]?.texture);
}
function texture(p){
  if(!p?.startsWith('res://art/full/'))failures.push('Non-HD runtime binding: '+p);
  else if(!fs.existsSync(project+'/'+p.slice(6)))failures.push('Missing texture: '+p);
  else textures.add(p);
}
let frames=0,originalFrames=0;
for(let id=0;id<=52;id++){
  const entry=manifest.atlases[String(id)];
  if(!entry){failures.push('Missing atlas type '+id);continue;}
  if(entry.frames.length!==entry.count)failures.push('Frame contract mismatch: '+id);
  for(let i=0;i<entry.count;i++){
    const frame=entry.frames[i];frames++;
    if(!frame){failures.push(`Missing mapping ${id}/${i}`);continue;}
    if(frame.original){originalFrames++;failures.push(`Original frame ${id}/${i}`);}
    else if(!frame.skip)texture(frame.texture||entry.texture);
  }
}
for(let i=0;i<117;i++)texture(manifest.officers[String(i)]?.texture);
for(const entry of Object.values(manifest.runtimeAssets||{}))texture(entry.texture);
const maps=JSON.parse(fs.readFileSync(project+'/art/full/maps/manifest.json'));
if(Object.keys(maps.maps).length!==34)failures.push('Expected 34 redrawn maps');
if(Object.keys(manifest.terrain).length!==14)failures.push('Expected 14 terrain banks');
let pages=0;
for(const p of catalog.pages.filter(x=>x.sourceId<=51)){
  const path=`${dir}/deliveries/${p.assetId}.json`;
  if(!fs.existsSync(path)){failures.push('Missing delivery '+p.assetId);continue;}
  const record=JSON.parse(fs.readFileSync(path));
  if(record.validation?.structure!=='pass')failures.push('Unvalidated delivery '+p.assetId);
  if(crypto.createHash('sha256').update(fs.readFileSync(p.target)).digest('hex')!==record.sha256)failures.push('Changed delivery '+p.assetId);
  pages++;
}
const report={schemaVersion:1,scope:'HD-only gameplay project; original research banks remain outside the runtime project',pass:failures.length===0,atlasTypes:Object.keys(manifest.atlases).length,buildingTypes:27,unitTypes:26,portraits:117,terrainBanks:14,maps:Object.keys(maps.maps).length,animationPages:pages,frameMappings:frames,originalFrameFallbacks:originalFrames,uniqueRuntimeTextures:textures.size,failures};
fs.writeFileSync(dir+'/runtime-hd-coverage.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
if(failures.length)process.exitCode=1;
