#!/usr/bin/env node
// 从原版银行与主数据表建立全量工作清单。源图是解码参考，不计入重绘完成数。
import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
import path from 'node:path';
import { parseUnitExp } from '../lib/exptable.mjs';
import { parseDataExp } from '../lib/dataexp.mjs';
import { loadBank, decodeFrame } from '../lib/unitdec.mjs';
import { writePng } from '../lib/unit2png.mjs';
import { readFrames, extractFrame, readPal } from '../lib/lwc2png.mjs';
import { parseGroundExp } from '../lib/terrain_bake.mjs';

const root = process.cwd();
const out = 'godot/chibi_remake/art/production';
const runtime = 'godot/chibi_remake/art/full';
const references = `${out}/references`;
for (const dir of [out, references, runtime, `${runtime}/buildings`, `${runtime}/units`, `${runtime}/officers`, `${runtime}/terrain`, `${runtime}/backgrounds`]) fs.mkdirSync(dir, {recursive:true});
const registry = parseUnitExp('_work/iso/SET/UNIT.EXP');
const data = parseDataExp('_work/iso/SET/DATA.EXP');
const bank = loadBank('_work/iso/BMP/UNIT.LWC', '_work/iso/BMP/UNIT.IDX');
const palette = readPal('_work/iso/RES/BATTLE.PAL');
const names = new Map([...data.buildings,...data.units].map(x=>[x.id,x.name]));
const jobs = [];
const preserved = fs.existsSync(`${out}/catalog.json`) ? new Map(JSON.parse(fs.readFileSync(`${out}/catalog.json`)).assets.map(x=>[x.assetId,x])) : new Map();
function add(job) {
  const old = preserved.get(job.assetId);
  jobs.push({...job,status:job.status||'pending',...(old?{status:old.status,delivery:old.delivery,validation:old.validation}:{} )});
}

for (const record of registry.units) {
  const source = record.id === 52 ? registry.units.find(x=>x.id===48) : record;
  const category = record.id <= 26 ? 'buildings' : 'units';
  const cols = category === 'buildings' ? Math.min(4,source.frameCount) : 8;
  const rows = Math.ceil(source.frameCount/cols);
  const W = cols*source.width, H = rows*source.height;
  const pixels=Buffer.alloc(W*H);
  const nonvisual=[];
  const frameBounds=[];
  for(let frame=0;frame<source.frameCount;frame++) {
    const decoded=decodeFrame(bank,source.firstFrame+frame,{teamOffset:31});
    const colors=new Set(decoded.px);
    const ink=decoded.px.reduce((s,c)=>s+(c!==0?1:0),0);
    const label = colors.size <=6 && ink >20 && ink/(decoded.w*decoded.h)<0.1;
    const blank = ink===0;
    if(label||blank)nonvisual.push({frame,reason:label?'source-size-label':'empty'});
    let left=decoded.w,top=decoded.h,right=-1,bottom=-1;
    for(let y=0;y<decoded.h;y++)for(let x=0;x<decoded.w;x++)if(decoded.px[y*decoded.w+x]) {left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
    frameBounds.push(right<0?null:[left,top,right-left+1,bottom-top+1]);
    const x=(frame%cols)*source.width,y=Math.floor(frame/cols)*source.height;
    if(!label&&!blank)for(let row=0;row<decoded.h;row++)pixels.set(decoded.px.subarray(row*decoded.w,(row+1)*decoded.w),(y+row)*W+x);
  }
  const key=String(record.id).padStart(3,'0');
  const reference=`${references}/${category}-${key}-source.png`;
  writePng(reference,W,H,pixels,palette);
  add({assetId:`${category}-${key}`,category,sourceId:record.id,name:names.get(record.id)||record.name,sourceBank:'UNIT.LWC',sourceFirstFrame:source.firstFrame,sourceFrameCount:source.frameCount,aliasSourceId:record.id===52?48:null,columns:cols,rows,frameWidth:source.width,frameHeight:source.height,frameBounds,nonvisualFrames:nonvisual,reference:path.resolve(reference),target:`${runtime}/${category}/${key}-atlas-v1.png`,transparent:true,expectedCoverage:'all source visual frames, all directions and stages; label cards remain blank'});
}
const groundNames=['草土','土砾','浅色土砾','水域','青水域','混合地表','砖墙','草顶土崖','岩壁','城垛墙','红土坡','草坡','木栅栏','地面道具'];
const grounds=parseGroundExp('_work/iso/SET');
const lib=readFrames('_work/iso/BMP/LIB.LWC','_work/iso/BMP/LIB.IDX');
for(const frame of lib) {
  const reference=`${references}/terrain-${String(frame.i).padStart(2,'0')}-source.png`;
  writePng(reference,frame.width,frame.height,extractFrame(frame),palette);
  add({assetId:`terrain-${String(frame.i).padStart(2,'0')}`,category:'terrain',sourceId:frame.i,name:groundNames[frame.i],sourceBank:'LIB.LWC',columns:frame.width/44,rows:frame.height/grounds[frame.i].H,frameWidth:44,frameHeight:grounds[frame.i].H,reference:path.resolve(reference),target:`${runtime}/terrain/${String(frame.i).padStart(2,'0')}-atlas-v1.png`,transparent:true,expectedCoverage:'all original tiles with identical 2:1 silhouettes, heights and seam relationships'});
}
let globalIndex=0;
// Preserve source IDs and raw names, including proprietary-font glyphs. Do not silently rename gameplay records.
const proposedNames={30:'严畯',50:'夏侯惇',51:'夏侯渊',57:'夏侯兰',69:'张颌',87:'毛玠',92:'张郃',93:'荀彧',112:'李珪'};
for(let faction=0;faction<data.officerBlocks.length;faction++)for(const officer of data.officerBlocks[faction]) {
  const id=globalIndex++;
  const raw=officer.name;
  const name=proposedNames[id]||raw.replace(/\s+/g,'');
  add({assetId:`officer-${String(id).padStart(3,'0')}`,category:'officers',sourceId:id,faction:faction+1,name,rawName:raw,nameProposed:!!proposedNames[id],might:officer.might,intellect:officer.intellect,tier:officer.tier,reference:null,target:`${runtime}/officers/${String(id).padStart(3,'0')}-portrait-v1.png`,transparent:false,expectedCoverage:'one distinct face; square bust portrait; no embedded text',sourceNote:'DATA.EXP identity; individual original portraits not yet identified'});
}
// Large UI/background surfaces; smaller BMP bank assets remain separately inventoried for later classification.
const bmp=readFrames('_work/iso/BMP/BMP.LWC','_work/iso/BMP/BMP.IDX');
const backgrounds=bmp.filter(x=>x.width>=320&&x.height>=180);
for(const frame of backgrounds) {
  const key=String(frame.i).padStart(3,'0');
  const reference=`${references}/background-bmp-${key}-source.png`;
  const bgPal=readPal(`_work/iso/RES/${frame.i===54?'MAINBACK':'BATTLE'}.PAL`);
  writePng(reference,frame.width,frame.height,extractFrame(frame),bgPal);
  add({assetId:`background-bmp-${key}`,category:'backgrounds',sourceId:frame.i,name:frame.i===54?'主菜单书桌':`BMP 背景/界面 ${frame.i}`,sourceBank:'BMP.LWC',reference:path.resolve(reference),target:`${runtime}/backgrounds/bmp-${key}-v1.png`,transparent:false,expectedCoverage:'faithful source composition; separate text from artwork',sourceNote:frame.i===54?'menu palette verified; existing remaster available':'palette/semantic classification requires visual validation'});
}
const picture=readFrames('_work/iso/BMP/PICTURE.LWC','_work/iso/BMP/PICTURE.IDX');
for(const frame of picture) add({assetId:`background-picture-${frame.i}`,category:'backgrounds',sourceId:frame.i,name:`PICTURE 背景 ${frame.i}`,sourceBank:'PICTURE.LWC',reference:null,target:`${runtime}/backgrounds/picture-${frame.i}-v1.png`,transparent:false,status:'source-unresolved',sourceNote:'must identify correct palette and scene before faithful redrawing'});
const other=readFrames('_work/iso/BMP/OTHER.LWC','_work/iso/BMP/OTHER.IDX');
const mouse=readFrames('_work/iso/RES/MOUSE.LWC','_work/iso/RES/MOUSE.IDX');
const maps=fs.readdirSync('_work/iso/MEDS').filter(x=>/\.med$/i.test(x)).map(x=>x.replace(/\.med$/i,'').toLowerCase()).sort();
const summary={buildings:jobs.filter(x=>x.category==='buildings').length,unitTypes:jobs.filter(x=>x.category==='units').length,officers:jobs.filter(x=>x.category==='officers').length,terrainGroups:lib.length,backgroundSurfaces:backgrounds.length+picture.length,maps:maps.length,sourceUnitFrames:bank.idx.length,additionalUiFrames:bmp.length-backgrounds.length,effectAtlases:other.length,cursorAtlases:mouse.length};
const catalog={schemaVersion:1,date:'2026-10-13',scope:'Full original game visual remake; not limited to current three maps',direction:'保留原版轮廓与配色，重绘材质和细节',summary,maps,assets:jobs,additionalBanks:{ui:bmp.filter(x=>!backgrounds.includes(x)).map(x=>({frame:x.i,width:x.width,height:x.height,status:'unclassified'})),effects:other.map(x=>({frame:x.i,width:x.width,height:x.height,status:'pending'})),cursors:mouse.map(x=>({frame:x.i,width:x.width,height:x.height,status:'pending'}))}};
writeCatalog(`${out}/catalog.json`,catalog);
console.log(JSON.stringify(summary));
console.log(`Inventory: ${jobs.length} primary assets, ${summary.additionalUiFrames} other UI frames; source references are not finished art.`);
