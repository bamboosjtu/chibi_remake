import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const input=process.argv[2];
if(!input||process.argv.length!==3)throw Error('Usage: node tools/install_campaign_media.mjs <local folder of approved chapter MP4s>');
const project=fileURLToPath(new URL('../godot/chibi_remake/',import.meta.url));
const media=path.join(project,'media/videos');
const catalog=JSON.parse(fs.readFileSync(path.join(project,'data/db/video_catalog.json'),'utf8')).files;
const entries=Object.entries(catalog).filter(([,entry])=>entry.localOnly);
const verify=(file,entry)=>{
  const bytes=fs.readFileSync(file);
  if(bytes.length!==entry.bytes||createHash('sha256').update(bytes).digest('hex')!==entry.sha256){
    throw Error('Local campaign media can be installed only from the approved, catalog-matched files: '+file);
  }
};
for(const [name,entry] of entries){
  if(!/^(CAO|LIU)[0-9]+[A-Z]?\.mp4$/.test(name))throw Error('Unsafe campaign video name: '+name);
  verify(path.join(input,name),entry);
  const target=path.join(media,name);
  if(fs.existsSync(target))verify(target,entry);
}
fs.mkdirSync(media,{recursive:true});
for(const [name,entry] of entries){
  const target=path.join(media,name);
  if(!fs.existsSync(target))fs.copyFileSync(path.join(input,name),target,fs.constants.COPYFILE_EXCL);
  verify(target,entry);
}
console.log('LOCAL CAMPAIGN MEDIA PASS '+entries.length+' checked files (no network; not tracked or published)');
