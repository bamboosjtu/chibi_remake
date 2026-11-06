#!/usr/bin/env node
// 从原版 BMP.LWC 281 帧直接解码并提取117个人像：59x74、10列；这是源资料提取。
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import path from 'node:path';
import {readFrames,extractFrame,readPal} from '../lib/lwc2png.mjs';
import {writeRgbPng} from '../lib/lwc_sheet.mjs';
const dir='godot/chibi_remake/art/production';
const filename=`${dir}/catalog.json`;
const catalog=JSON.parse(fs.readFileSync(filename));
const bmp=readFrames('_work/iso/BMP/BMP.LWC','_work/iso/BMP/BMP.IDX');
const portrait=bmp[281],pixels=extractFrame(portrait),pal=readPal('_work/iso/RES/BATTLE.PAL');
if(portrait.width!==590||portrait.height!==888)throw new Error('Unexpected portrait sheet');
for(const asset of catalog.assets.filter(x=>x.category==='officers')) {
  const index=asset.sourceId,x0=(index%10)*59,y0=Math.floor(index/10)*74,rgb=Buffer.alloc(59*74*3);
  for(let y=0;y<74;y++)for(let x=0;x<59;x++){
    const c=pal[pixels[(y+y0)*portrait.width+x+x0]],p=(y*59+x)*3;
    rgb[p]=c[0];rgb[p+1]=c[1];rgb[p+2]=c[2];
  }
  const reference=`${dir}/references/officer-${String(index).padStart(3,'0')}-source.png`;
  writeRgbPng(reference,59,74,rgb);
  asset.reference=path.resolve(reference);
  asset.target=`godot/chibi_remake/art/full/officers/${String(index).padStart(3,'0')}-portrait-v2.png`;
  asset.sourceBank='BMP.LWC';asset.sourceFrame=281;asset.sourceRect=[x0,y0,59,74];asset.palette='BATTLE.PAL';
  asset.sourceNote='Original portrait sheet; 59x74 10-column source grid matches FUN_00405e80 portrait rect operations in retained decompilation';
  asset.expectedCoverage='preserve original facial identity, headgear, pose and palette; high-definition redraw';
}
const pics=readFrames('_work/iso/BMP/PICTURE.LWC','_work/iso/BMP/PICTURE.IDX');
const paletteNames=['BEGIN','WAIT','END','FAIL'],sceneNames=['开场画面','等待画面','结束画面','兵败赤壁'];
for(const asset of catalog.assets.filter(x=>x.category==='backgrounds')) {
  let paletteName,sourceFrame;
  if(asset.sourceBank==='PICTURE.LWC') {
    sourceFrame=pics[asset.sourceId];paletteName=paletteNames[asset.sourceId];asset.name=sceneNames[asset.sourceId];
    asset.status='pending';asset.sourceNote='FUN_0041a5a0(0/1/2/3) explicitly pairs frames 0/1/2/3 with BEGIN/WAIT/END/FAIL palettes (retained decompilation, static evidence)';
  } else {
    sourceFrame=bmp[asset.sourceId];
    const bytes=extractFrame(sourceFrame);
    const matched=pics.find(x=>x.width===sourceFrame.width&&x.height===sourceFrame.height&&extractFrame(x).equals(bytes));
    paletteName=matched?paletteNames[matched.i]:[19,54,55,56].includes(asset.sourceId)?'MAINBACK':'BATTLE';
    if(matched)asset.aliasPictureFrame=matched.i;
    asset.sourceNote=matched?'Pixel-identical to PICTURE frame with statically paired palette':asset.sourceId===281?'Portrait sheet, derived from 117 individually redrawn portraits; not a scene background':`${paletteName} palette visually reviewed; detailed UI semantics retained in source`;
  }
  const palette=readPal(`_work/iso/RES/${paletteName}.PAL`),px=extractFrame(sourceFrame),rgb=Buffer.alloc(px.length*3);
  for(let i=0;i<px.length;i++){rgb[i*3]=palette[px[i]][0];rgb[i*3+1]=palette[px[i]][1];rgb[i*3+2]=palette[px[i]][2];}
  const reference=`${dir}/references/${asset.assetId}-source.png`;
  writeRgbPng(reference,sourceFrame.width,sourceFrame.height,rgb);
  asset.reference=path.resolve(reference);asset.palette=`${paletteName}.PAL`;
  if(asset.sourceBank==='BMP.LWC'&&asset.sourceId===281)asset.derivedFromPortraits=true;
}
catalog.revision='full-v2-original-portrait-identities';
writeCatalog(filename,catalog);
console.log('117 original portrait references extracted; four PICTURE palette pairs recovered; palette candidates refreshed.');
