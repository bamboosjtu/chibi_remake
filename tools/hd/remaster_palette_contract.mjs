#!/usr/bin/env node
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import {readFrames,extractFrame,readPal} from '../lib/lwc2png.mjs';
const filename='godot/chibi_remake/art/production/catalog.json';
const catalog=JSON.parse(fs.readFileSync(filename));
const bank=readFrames('_work/iso/BMP/LIB.LWC','_work/iso/BMP/LIB.IDX'),palette=readPal('_work/iso/RES/BATTLE.PAL');
for(const asset of catalog.assets.filter(x=>x.category==='terrain')) {
  const counts=new Map();let total=0;
  for(const value of extractFrame(bank[asset.sourceId]))if(value){total++;counts.set(value,(counts.get(value)||0)+1);}
  asset.dominantColors=[...counts].sort((a,b)=>b[1]-a[1]).slice(0,6).map(([index,count])=>({index,hex:'#'+palette[index].map(x=>x.toString(16).padStart(2,'0')).join(''),fraction:count/total}));
}
writeCatalog(filename,catalog);
console.log('14 source palette contracts saved.');
