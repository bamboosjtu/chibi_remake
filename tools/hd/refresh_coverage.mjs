// Refresh coverage metadata from accepted frame mappings; never regenerate archival images.
import fs from 'node:fs';
import crypto from 'node:crypto';
const dir='godot/chibi_remake/art/production',project='godot/chibi_remake';
const coverage=JSON.parse(fs.readFileSync(dir+'/coverage.json'));
const manifest=JSON.parse(fs.readFileSync(project+'/art/full/manifest.json'));
const catalog=JSON.parse(fs.readFileSync(dir+'/catalog.json'));
coverage.primary=catalog.assets.map(asset=>{
  if(['units','buildings'].includes(asset.category)){
    const hd=manifest.atlases[asset.sourceId];
    return {assetId:asset.assetId,frames:Array.from({length:asset.sourceFrameCount},(_,i)=>({frame:i,mode:hd?(hd.frames[i]?.original?'source-fallback':hd.frames[i]?.skip?'nonvisual':'redrawn'):'source-fallback',sourceFrame:asset.sourceFirstFrame+i,sourceAsset:`source-UNIT-${asset.sourceFirstFrame+i}`}))};
  }
  return {assetId:asset.assetId,mode:fs.existsSync(asset.target)?'redrawn':'source-fallback',sourceBank:asset.sourceBank,sourceId:asset.sourceId};
});
coverage.allRemade=false; // Unused archival interface, illustration, effect and cursor banks remain separate.
coverage.runtimeCoverage='runtime-hd-coverage.json';
delete coverage.contentRevision;
coverage.contentRevision=crypto.createHash('sha256').update(JSON.stringify(coverage)).digest('hex');
fs.writeFileSync(dir+'/coverage.json',JSON.stringify(coverage,null,2));
console.log('Updated archival coverage metadata without repainting or recreating low-resolution images.');
