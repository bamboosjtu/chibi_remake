import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {execFileSync} from 'node:child_process';
const args=process.argv.slice(2),root=path.resolve(args.includes('--source')?args[args.indexOf('--source')+1]:'source/terrain');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const manifestPath=path.join(root,'inputs.json');
if(args.includes('--write')){
 const files=[];function walk(directory,relative=''){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){const name=path.posix.join(relative,entry.name);if(entry.isDirectory())walk(path.join(directory,entry.name),name);else if(name!=='inputs.json'&&name!=='README.md'&&!entry.name.startsWith('.')){const b=fs.readFileSync(path.join(directory,entry.name));files.push({path:name,bytes:b.length,sha256:sha(b)});}}}walk(root);
 fs.writeFileSync(manifestPath,JSON.stringify({schemaVersion:1,files},null,2)+'\n');
}
const manifest=JSON.parse(fs.readFileSync(manifestPath));
for(const file of manifest.files){
 const relative=path.relative(process.cwd(),path.join(root,file.path)).split(path.sep).join('/');
 if(args.includes('--index')){
  const blob=execFileSync('git',['show',':'+relative]);
  if(file.path.endsWith('.png')){
   const pointer=blob.toString();if(!pointer.includes('oid sha256:'+file.sha256)||!pointer.includes('size '+file.bytes))throw Error('Source LFS pointer differs: '+relative);
  }else if(sha(blob)!==file.sha256)throw Error('Staged source differs: '+relative);
 }else{
  const target=path.resolve(root,file.path);
  if(!target.startsWith(root+path.sep)||!fs.existsSync(target)||sha(fs.readFileSync(target))!==file.sha256)throw Error('Source input missing or changed: '+file.path);
 }
}
console.log('TERRAIN SOURCES PASS '+manifest.files.length+' versioned source inputs'+(args.includes('--index')?' / index and LFS':' / SHA256'));
