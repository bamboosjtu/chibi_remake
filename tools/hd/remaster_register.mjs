#!/usr/bin/env node
// 每个生成任务独立落盘记录，避免并行生成对共享清单的覆盖。
import fs from 'node:fs';
import {assertUnpublishedTarget} from '../lib/catalog_io.mjs';
import path from 'node:path';
import crypto from 'node:crypto';
const [assetId,source,promptFile]=process.argv.slice(2);
const directory='godot/chibi_remake/art/production';
const catalog=JSON.parse(fs.readFileSync(`${directory}/catalog.json`));
const asset=[...catalog.assets,...(catalog.pages||[])].find(x=>x.assetId===assetId);
if(!asset)throw new Error(`Unknown asset: ${assetId}`);
const data=fs.readFileSync(source);
if(data.subarray(1,4).toString()!=='PNG')throw new Error('Not a PNG');
const existingRecord=`${directory}/deliveries/${assetId}.json`;
if(fs.existsSync(existingRecord)){
  const previous=JSON.parse(fs.readFileSync(existingRecord));
  if(previous.texture===asset.target&&previous.sha256===crypto.createHash('sha256').update(data).digest('hex')){
    console.log(JSON.stringify({assetId,status:'unchanged',validation:previous.validation}));
    process.exit(0);
  }
}
const destination=path.resolve(asset.target);
fs.mkdirSync(path.dirname(destination),{recursive:true});
assertUnpublishedTarget(asset,data);
fs.copyFileSync(source,destination);
const width=data.readUInt32BE(16),height=data.readUInt32BE(20),colorType=data[25];
const entry={assetId,status:'generated-awaiting-validation',generator:'built-in image_gen',sourceGeneratedFile:source,texture:asset.target,width,height,colorType,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex'),promptFile:promptFile||null,generatedAt:new Date().toISOString()};
// 队列会随进度改写；把实际任务提示复制进交付记录以保留来源。
if(promptFile&&fs.existsSync(promptFile)) {
  const records=JSON.parse(fs.readFileSync(promptFile));
  const job=Array.isArray(records)?records.find(x=>x.assetId===assetId):records[assetId];
  if(job?.prompt)entry.prompt=job.prompt;
}
fs.mkdirSync(`${directory}/deliveries`,{recursive:true});
const previous=`${directory}/deliveries/${assetId}.json`;
if(fs.existsSync(previous)) {
  const old=JSON.parse(fs.readFileSync(previous));
  if(old.sha256!==entry.sha256) {
    fs.mkdirSync(`${directory}/deliveries/history`,{recursive:true});
    fs.copyFileSync(previous,`${directory}/deliveries/history/${assetId}-${old.sha256.slice(0,12)}.json`);
  }
}
fs.writeFileSync(`${directory}/deliveries/${assetId}.json`,JSON.stringify(entry,null,2));
console.log(JSON.stringify({assetId,width,height,path:asset.target,status:entry.status}));
