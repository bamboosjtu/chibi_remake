#!/usr/bin/env node
// 将动作较多的兵种拆成32帧页面，保持每帧的实际分辨率，而非放大低清合图。
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import path from 'node:path';
import {loadBank,decodeFrame} from '../lib/unitdec.mjs';
import {readPal} from '../lib/lwc2png.mjs';
import {writePng} from '../lib/unit2png.mjs';
const dir='godot/chibi_remake/art/production';
const file=`${dir}/catalog.json`;
const catalog=JSON.parse(fs.readFileSync(file));
const bank=loadBank('_work/iso/BMP/UNIT.LWC','_work/iso/BMP/UNIT.IDX');
const palette=readPal('_work/iso/RES/BATTLE.PAL');
catalog.pages=[];
for(const asset of catalog.assets.filter(x=>x.category==='units')) {
  asset.pages=[];
  for(let start=0,page=0;start<asset.sourceFrameCount;start+=32,page++) {
    const count=Math.min(32,asset.sourceFrameCount-start),cols=Math.min(4,count),rows=Math.ceil(count/cols);
    const id=`${asset.assetId}-page-${String(page).padStart(2,'0')}`;
    const W=cols*asset.frameWidth,H=rows*asset.frameHeight,pixels=Buffer.alloc(W*H);
    const nonvisual=asset.nonvisualFrames.filter(x=>x.frame>=start&&x.frame<start+count).map(x=>({...x,frame:x.frame-start}));
    const excluded=new Set(nonvisual.map(x=>x.frame));
    for(let i=0;i<count;i++) {
      if(excluded.has(i))continue;
      const decoded=decodeFrame(bank,asset.sourceFirstFrame+start+i,{teamOffset:31});
      const x=(i%cols)*asset.frameWidth,y=Math.floor(i/cols)*asset.frameHeight;
      for(let row=0;row<decoded.h;row++)pixels.set(decoded.px.subarray(row*decoded.w,(row+1)*decoded.w),(y+row)*W+x);
    }
    const reference=`${dir}/references/${id}-source.png`;
    writePng(reference,W,H,pixels,palette);
    const pageAsset={...asset,assetId:id,category:'unit-pages',parentAssetId:asset.assetId,pageIndex:page,startFrame:start,sourceFrameCount:count,columns:cols,rows,nonvisualFrames:nonvisual,frameBounds:asset.frameBounds.slice(start,start+count),reference:path.resolve(reference),target:`godot/chibi_remake/art/full/units/${String(asset.sourceId).padStart(3,'0')}/page-${String(page).padStart(2,'0')}-v1.png`,status:'pending'};
    delete pageAsset.pages;
    catalog.pages.push(pageAsset);asset.pages.push(id);
  }
}
writeCatalog(file,catalog);
console.log(JSON.stringify({unitTypes:26,pages:catalog.pages.length,maximumFramesPerPage:32}));
