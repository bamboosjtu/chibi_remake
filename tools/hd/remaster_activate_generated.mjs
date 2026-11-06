import fs from 'node:fs';
import {writeCatalog} from '../lib/catalog_io.mjs';
const dir='godot/chibi_remake/art/production';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const write=(p,v)=>fs.writeFileSync(p,JSON.stringify(v,null,2)+'\n');
const catalog=read(`${dir}/catalog.json`);
if(catalog.visualReviewPolicy?.reviewer==='user'){
  console.log('Historical activation already completed. Keep accepted versions; register future work under new version paths.');
  process.exit(0);
}
const old=read(`${dir}/catalog-before-animation-groups.json`);
const acceptance={date:'2026-10-13',reviewer:'user',reason:'用户已人工验证高清图，要求直接替换对应素材，不再逐项美术复核。'};
if(!fs.existsSync(`${dir}/catalog-before-user-activation.json`))write(`${dir}/catalog-before-user-activation.json`,catalog);
for(const a of catalog.assets){
  const file=`${dir}/deliveries/${a.assetId}.json`;
  if(!fs.existsSync(file))continue;
  const d=read(file);
  if(!fs.existsSync(d.texture))continue;
  a.target=d.texture;
  a.status='user-accepted';
  d.validation={...d.validation,visual:'pass'};
  d.userAcceptance=acceptance;
  write(file,d);
}
// 已生成分页保留原来的格位，只更新真实的源帧分类。
for(const id of [27,28,29,30,31]){
  const parent=catalog.assets.find(a=>a.assetId===`units-${String(id).padStart(3,'0')}`);
  const previous=old.assets.find(a=>a.assetId===parent.assetId);
  const pages=old.pages.filter(a=>a.parentAssetId===parent.assetId);
  parent.pages=previous.pages;
  catalog.pages=catalog.pages.filter(a=>a.parentAssetId!==parent.assetId);
  for(const page of pages){
    page.teamTintable=parent.teamTintable;
    page.nonvisualFrames=parent.nonvisualFrames.filter(f=>f.frame>=page.startFrame&&f.frame<page.startFrame+page.sourceFrameCount).map(f=>({...f,frame:f.frame-page.startFrame}));
    if(id===29)page.originalFrames=[29,34].filter(f=>f>=page.startFrame&&f<page.startFrame+page.sourceFrameCount).map(f=>f-page.startFrame);
    page.status='user-accepted';
    const file=`${dir}/deliveries/${page.assetId}.json`;
    const d=read(file);
    d.validation={...d.validation,visual:'pass'};
    d.userAcceptance=acceptance;
    write(file,d);
    catalog.pages.push(page);
  }
}
const whole=catalog.assets.find(a=>a.assetId==='units-032');
whole.pages=[];
catalog.pages=catalog.pages.filter(a=>a.parentAssetId!==whole.assetId);
catalog.assets.find(a=>a.assetId==='buildings-021').originalFrames=[3];
catalog.visualReviewPolicy=acceptance;
catalog.revision='user-accepted-generated-assets-active';
writeCatalog(`${dir}/catalog.json`,catalog);
console.log('Activated existing targets, 16 generated animation pages, 117 portraits and 14 terrain atlases. Three undrawn source frames retained.');
