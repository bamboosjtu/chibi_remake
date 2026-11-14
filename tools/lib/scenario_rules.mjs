import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export function definitions(){return JSON.parse(fs.readFileSync(path.join(root,'tools/inputs/scenario_rules.source.json'),'utf8'));}
export function eventIndex(raw){
 const names=new TextDecoder('gbk').decode(Buffer.from(raw.map(x=>x^0x46))).split('\0\0').filter(Boolean);
 const events={schemaVersion:1,events:{}};
 for(let i=0;i<names.length;i++)events.events[i]=/\.avi$/i.test(names[i])?{video:`res://media/videos/${names[i].toUpperCase()}`,source:names[i]}:{text:names[i]};
 return events;
}
export function commitOutputs(outputs){
 if(new Set(outputs.map(([file])=>path.resolve(file))).size!==outputs.length)throw Error('Duplicate output target');
 const staged=[];let success=false;
 try{
  for(const [file,data] of outputs){
   const id=crypto.randomUUID(),temporary=file+'.tmp-'+id,backup=file+'.previous-'+id;
   fs.writeFileSync(temporary,JSON.stringify(data,null,2)+'\n');staged.push({file,temporary,backup,hadOriginal:fs.existsSync(file),backedUp:false,committed:false});
  }
  for(const item of staged){
   if(item.hadOriginal){fs.renameSync(item.file,item.backup);item.backedUp=true;}
   fs.renameSync(item.temporary,item.file);item.committed=true;
  }
  success=true;
 }catch(error){
  const recovery=[];
  for(const item of [...staged].reverse())try{
   if(item.committed)fs.unlinkSync(item.file);
   if(item.backedUp){fs.renameSync(item.backup,item.file);item.backedUp=false;}
  }catch(restoreError){recovery.push(item.backup+': '+restoreError.message);}
  if(recovery.length)throw new AggregateError([error,...recovery],'Generation failed; retained recovery backups: '+recovery.join('; '));
  throw error;
 }finally{
  for(const item of staged){if(fs.existsSync(item.temporary))fs.unlinkSync(item.temporary);if(success&&item.backedUp)fs.unlinkSync(item.backup);}
 }
}
export function generate(args=[]){
 const value=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
 const output=path.resolve(value('--output',path.join(root,'godot/chibi_remake/data/db')));
 const outputs=[[path.join(output,'scenario_rules.json'),definitions()]];
 // Read and decode every required input BEFORE touching any output.
 if(!args.includes('--rules-only'))outputs.push([path.join(output,'events.json'),eventIndex(fs.readFileSync(path.resolve(value('--events',path.join(root,'_work/iso/SET/EVENTEX.EXT')))))]);
 if(args.includes('--check')){
  for(const [file,data] of outputs)if(JSON.stringify(JSON.parse(fs.readFileSync(file,'utf8')))!==JSON.stringify(data))throw Error('Generated rule drift: '+file);
 }else commitOutputs(outputs);
 console.log('SCENARIO RULES PASS '+(args.includes('--check')?'equivalent':'generated')+' /mission29 exit / explicit sides and outcomes');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))generate(process.argv.slice(2));
