#!/usr/bin/env node
// 从原始索引色提取每格覆盖范围；不将参考图或上采样记为重绘。
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import {readFrames, extractFrame} from '../lib/lwc2png.mjs';
const filename='godot/chibi_remake/art/production/catalog.json';
const catalog=JSON.parse(fs.readFileSync(filename));
const bank=readFrames('_work/iso/BMP/LIB.LWC','_work/iso/BMP/LIB.IDX');
for(const asset of catalog.assets.filter(x=>x.category==='terrain')) {
  const source=bank[asset.sourceId],px=extractFrame(source);
  asset.frameBounds=[];asset.nonvisualFrames=[];
  asset.sourceFrameCount=asset.columns*asset.rows;
  for(let frame=0;frame<asset.sourceFrameCount;frame++) {
    const x0=(frame%asset.columns)*asset.frameWidth,y0=Math.floor(frame/asset.columns)*asset.frameHeight;
    let left=asset.frameWidth,top=asset.frameHeight,right=-1,bottom=-1;
    for(let y=0;y<asset.frameHeight;y++)for(let x=0;x<asset.frameWidth;x++)if(px[(y0+y)*source.width+x0+x]) {
      left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);
    }
    asset.frameBounds.push(right<0?null:[left,top,right-left+1,bottom-top+1]);
    if(right<0)asset.nonvisualFrames.push({frame,reason:'empty-source-tile'});
  }
}
writeCatalog(filename,catalog);
console.log('14 terrain contracts: source bounds and empty cells recorded.');
