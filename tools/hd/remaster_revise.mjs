#!/usr/bin/env node
import fs from 'node:fs';
const dir='godot/chibi_remake/art/production',filename=`${dir}/catalog.json`;
const catalog=JSON.parse(fs.readFileSync(filename));
for(const id of process.argv.slice(2)) {
  const asset=[...catalog.assets,...(catalog.pages||[])].find(x=>x.assetId===id);
  if(!asset)throw new Error(`Unknown asset ${id}`);
  const old=asset.target;
  const match=old.match(/-v(\d+)\.png$/);
  if(!match)throw new Error(`Unversioned target ${old}`);
  const file=`${dir}/deliveries/${id}.json`;
  if(fs.existsSync(file)) {
    fs.mkdirSync(`${dir}/deliveries/history`,{recursive:true});
    fs.copyFileSync(file,`${dir}/deliveries/history/${id}-v${match[1]}.json`);
  }
  asset.previousTargets=[...(asset.previousTargets||[]),old];
  asset.target=old.replace(/-v\d+\.png$/,`-v${Number(match[1])+1}.png`);
  asset.status='revision-pending';
  console.log(`${id}: ${old} -> ${asset.target}`);
}
fs.writeFileSync(filename,JSON.stringify(catalog,null,2));
