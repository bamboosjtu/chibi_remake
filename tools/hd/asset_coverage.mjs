import fs from 'node:fs';
import crypto from 'node:crypto';
import {readFrames,extractFrame,readPal} from '../lib/lwc2png.mjs';
import {loadBank,decodeFrame} from '../lib/unitdec.mjs';
import {writePng} from '../lib/unit2png.mjs';
const project='godot/chibi_remake/';
const output=project+'art/source_fallback';fs.mkdirSync(output,{recursive:true});
const palette=readPal('_work/iso/RES/BATTLE.PAL');
const records=[];
for(const bank of ['BMP','LIB','OTHER','PICTURE','MOUSE']){
  const dir=bank==='MOUSE'?'RES':'BMP';
  const frames=readFrames(`_work/iso/${dir}/${bank}.LWC`,`_work/iso/${dir}/${bank}.IDX`);
  for(const f of frames){
    let paletteName='BATTLE';
    if(bank==='PICTURE')paletteName=['BEGIN','WAIT','END','FAIL'][f.i];
    if(bank==='BMP'&&[19,54,55,56].includes(f.i))paletteName='MAINBACK';
    const pal=paletteName==='BATTLE'?palette:readPal(`_work/iso/RES/${paletteName}.PAL`);
    const path=`art/source_fallback/${bank.toLowerCase()}-${f.i}.png`;
    writePng(project+path,f.width,f.height,extractFrame(f),pal);
    records.push({assetId:`source-${bank}-${f.i}`,bank,frame:f.i,texture:'res://'+path,mode:'source-fallback',palette:paletteName+'.PAL',paletteEvidence:bank==='PICTURE'||(bank==='BMP'&&[19,54,55,56].includes(f.i))?'scene-paired':'bank-default; caller must select scene palette if different'});
  }
}
const bank=loadBank('_work/iso/BMP/UNIT.LWC','_work/iso/BMP/UNIT.IDX');
for(let i=0;i<bank.idx.length;i++){
  const f=decodeFrame(bank,i,{teamOffset:31});
  const path=`art/source_fallback/unit-${i}.png`;
  writePng(project+path,f.w,f.h,f.px,palette);
  records.push({assetId:`source-UNIT-${i}`,bank:'UNIT',frame:i,texture:'res://'+path,mode:'source-fallback',palette:'BATTLE.PAL',teamOwner:2});
}
const manifest=JSON.parse(fs.readFileSync(project+'art/full/manifest.json'));
const catalog=JSON.parse(fs.readFileSync('godot/chibi_remake/art/production/catalog.json'));
const coverage={schemaVersion:1,sourceFrameFallbacks:records,primary:[],allRemade:false};
for(const asset of catalog.assets){
  if(['units','buildings'].includes(asset.category)){
    const hd=manifest.atlases[asset.sourceId];
    const frames=[];
    for(let i=0;i<asset.sourceFrameCount;i++)frames.push({frame:i,mode:hd?(hd.frames[i]?.original?'source-fallback':hd.frames[i]?.skip?'nonvisual':'redrawn'):'source-fallback',sourceFrame:asset.sourceFirstFrame+i,sourceAsset:`source-UNIT-${asset.sourceFirstFrame+i}`});
    coverage.primary.push({assetId:asset.assetId,frames});
  }else coverage.primary.push({assetId:asset.assetId,mode:fs.existsSync(asset.target)?'redrawn':'source-fallback',sourceBank:asset.sourceBank,sourceId:asset.sourceId,...(asset.category==='officers'?{sourceAsset:'source-BMP-281',sourceRect:[asset.sourceId%10*59,Math.floor(asset.sourceId/10)*74,59,74]}:{})});
}
coverage.contentRevision=crypto.createHash('sha256').update(JSON.stringify(coverage)).digest('hex');
fs.writeFileSync(project+'art/source_fallback/manifest.json',JSON.stringify(coverage));
fs.writeFileSync('godot/chibi_remake/art/production/coverage.json',JSON.stringify(coverage,null,2));
console.log('Explicit source fallback coverage:',records.length,'bank frames. New paintings are still tracked separately.');
