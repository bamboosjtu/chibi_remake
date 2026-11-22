#!/usr/bin/env node
// 保留原始动作分组；单色蓝色视觉帧不能用“颜色少”误判成尺寸标签。
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import path from 'node:path';
import {loadBank,decodeFrame,TEAM_LO,TEAM_HI} from '../lib/unitdec.mjs';
import {parseUnitExp} from '../lib/exptable.mjs';
import {readPal} from '../lib/lwc2png.mjs';
import {writePng} from '../lib/unit2png.mjs';
const dir='godot/chibi_remake/art/production',filename=`${dir}/catalog.json`;
const catalog=JSON.parse(fs.readFileSync(filename));
if(!fs.existsSync(`${dir}/catalog-before-animation-groups.json`))fs.copyFileSync(filename,`${dir}/catalog-before-animation-groups.json`);
const bank=loadBank('_work/iso/BMP/UNIT.LWC','_work/iso/BMP/UNIT.IDX');
const registry=parseUnitExp('_work/iso/SET/UNIT.EXP').units;
const palette=readPal('_work/iso/RES/BATTLE.PAL');
for(const asset of catalog.assets.filter(x=>['buildings','units'].includes(x.category))) {
  asset.nonvisualFrames=[];asset.flatSourceShapes=[];asset.teamTintable=false;
  for(let frame=0;frame<asset.sourceFrameCount;frame++) {
    const native=decodeFrame(bank,asset.sourceFirstFrame+frame,{teamOffset:0});
    const ink=Array.from(native.px).filter(x=>x!==0);
    const colors=new Set(ink);
    const label=ink.length>20&&ink.length/(native.w*native.h)<0.1&&colors.size<=6&&[...colors].every(x=>x>=248);
    if(!ink.length||label)asset.nonvisualFrames.push({frame,reason:label?'source-size-label':'empty'});
    const tint=ink.filter(x=>x>=TEAM_LO&&x<=TEAM_HI).length;
    if(tint>0)asset.teamTintable=true;
    const bounds=asset.frameBounds[frame];
    if(ink.length&&tint/ink.length>0.92&&bounds&&bounds[3]<asset.frameHeight*0.55)asset.flatSourceShapes.push(frame);
  }
  if(asset.category==='buildings') {
    const W=asset.columns*asset.frameWidth,H=asset.rows*asset.frameHeight,pixels=Buffer.alloc(W*H);
    const excluded=new Set(asset.nonvisualFrames.map(x=>x.frame));
    for(let frame=0;frame<asset.sourceFrameCount;frame++) {
      if(excluded.has(frame))continue;
      const d=decodeFrame(bank,asset.sourceFirstFrame+frame,{teamOffset:31});
      const x=(frame%asset.columns)*asset.frameWidth,y=Math.floor(frame/asset.columns)*asset.frameHeight;
      for(let r=0;r<d.h;r++)pixels.set(d.px.subarray(r*d.w,(r+1)*d.w),(y+r)*W+x);
    }
    const reference=`${dir}/references/${asset.assetId}-source-v2.png`;
    writePng(reference,W,H,pixels,palette);
    asset.reference=path.resolve(reference);
  }
}
catalog.pages=[];
for(const asset of catalog.assets.filter(x=>x.category==='units'&&x.sourceId!==52)) {
  const source=registry.find(x=>x.id===asset.sourceId);
  const cols=source.cols,rowsPerPage=Math.min(4,Math.max(1,Math.floor(32/cols))),pageSize=cols*rowsPerPage;
  asset.pages=[];asset.sourceGroupColumns=cols;
  for(let start=0,page=0;start<asset.sourceFrameCount;start+=pageSize,page++) {
    const count=Math.min(pageSize,asset.sourceFrameCount-start),rows=Math.ceil(count/cols);
    const id=`${asset.assetId}-page-${String(page).padStart(2,'0')}`;
    const W=cols*asset.frameWidth,H=rows*asset.frameHeight,pixels=Buffer.alloc(W*H);
    const nonvisual=asset.nonvisualFrames.filter(x=>x.frame>=start&&x.frame<start+count).map(x=>({...x,frame:x.frame-start}));
    const excluded=new Set(nonvisual.map(x=>x.frame));
    for(let i=0;i<count;i++) {
      if(excluded.has(i))continue;
      const decoded=decodeFrame(bank,asset.sourceFirstFrame+start+i,{teamOffset:31});
      const x=(i%cols)*asset.frameWidth,y=Math.floor(i/cols)*asset.frameHeight;
      for(let r=0;r<decoded.h;r++)pixels.set(decoded.px.subarray(r*decoded.w,(r+1)*decoded.w),(y+r)*W+x);
    }
    const reference=`${dir}/references/${id}-source-v2.png`;
    writePng(reference,W,H,pixels,palette);
    const record={...asset,assetId:id,category:'unit-pages',parentAssetId:asset.assetId,pageIndex:page,startFrame:start,sourceFrameCount:count,columns:cols,rows,nonvisualFrames:nonvisual,frameBounds:asset.frameBounds.slice(start,start+count),flatSourceShapes:asset.flatSourceShapes.filter(x=>x>=start&&x<start+count).map(x=>x-start),reference:path.resolve(reference),target:`godot/chibi_remake/art/full/units/${String(asset.sourceId).padStart(3,'0')}/page-${String(page).padStart(2,'0')}-v2.png`,status:'pending'};
    delete record.pages;
    catalog.pages.push(record);asset.pages.push(id);
  }
}
const alias=catalog.assets.find(x=>x.category==='units'&&x.sourceId===52);
alias.pages=[...catalog.assets.find(x=>x.category==='units'&&x.sourceId===48).pages];
alias.sourceNote='Original type 52 aliases type 48 bitmap frames; reuse the same redrawn visuals, do not invent a pennant.';
catalog.revision='full-v3-original-animation-groups';
writeCatalog(filename,catalog);
console.log(JSON.stringify({unitDefinitions:26,uniqueUnitSources:25,pages:catalog.pages.length,maxSourceRowsPerPage:4,blueVisualFramesPreserved:true}));
