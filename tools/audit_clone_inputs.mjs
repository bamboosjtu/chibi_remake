import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {PROJECT,readAssets,assetFiles,isAssetFile,isBinaryAsset,usesLfs} from './lib/runtime_assets.mjs';

function git(args,input) {
 const result=spawnSync('git',args,{input,maxBuffer:64*1024*1024});
 if(result.status!==0)throw Error(result.stderr.toString()||result.error?.message);
 return result.stdout;
}
const rows=readAssets();
const required=assetFiles(rows).map(file=>PROJECT+'/'+file);
if(process.argv.includes('--index')) {
 const entries=new Map(git(['ls-files','--stage','-z']).toString().split('\0').filter(Boolean).map(line=>{
  const [header,file]=line.split('\t');return [file,header.split(' ')[1]];
 }));
 const ignored=git(['ls-files','-ci','--exclude-standard','-z']).toString().split('\0').filter(Boolean);
 if(ignored.length)throw Error('Local-only files still tracked; remove with git rm --cached:\n'+ignored.slice(0,20).join('\n'));
 const allowed=new Set(required);
 for(const file of entries.keys()) {
  if(file.startsWith(PROJECT+'/art/full/terrain_chunks/')||file.startsWith(PROJECT+'/art/full/maps/'))throw Error('Derived terrain must not be tracked: '+file);
  // Only game resources belong to the runtime allowlist. Documentation artwork
  // is tracked source material and never enters the game staging contract.
  if(file.startsWith(PROJECT+'/')&&isAssetFile(file)&&!allowed.has(file))throw Error('Undeclared runtime asset tracked: '+file);
  if(/^research\/.*\.(py|js|mjs|ps1)$/.test(file)||/^_?rea(?:\/|-)/i.test(file))throw Error('Private research script tracked: '+file);
 }
 for(const file of required)if(!entries.has(file))throw Error('Required runtime asset/metadata not tracked: '+file);
 const large=rows.filter(row=>usesLfs(row.path));
 const attrs=git(['check-attr','filter','--stdin','-z'],Buffer.from(large.map(row=>PROJECT+'/'+row.path).join('\0')+'\0')).toString().split('\0');
 for(let i=0;i+2<attrs.length;i+=3)if(attrs[i+2]!=='lfs')throw Error('Runtime binary must use LFS: '+attrs[i]);
 const ids=[...new Set(large.map(row=>entries.get(PROJECT+'/'+row.path)))];
 if(ids.length) {
  const sizes=git(['cat-file','--batch-check'],ids.join('\n')+'\n').toString().trim().split('\n');
  for(const line of sizes)if(Number(line.split(' ')[2])>256)throw Error('Runtime binary is not an LFS pointer: '+line.split(' ')[0]);
  const data=git(['cat-file','--batch'],ids.join('\n')+'\n'),pointers=new Map();let cursor=0;
  for(const id of ids) {
   const end=data.indexOf(10,cursor),size=Number(data.subarray(cursor,end).toString().split(' ')[2]);
   const pointer=data.subarray(end+1,end+1+size).toString();cursor=end+size+2;
   if(!pointer.startsWith('version https://git-lfs.github.com/spec/v1\n'))throw Error('Invalid LFS pointer: '+id);
   pointers.set(id,{sha256:/oid sha256:([a-f0-9]{64})/.exec(pointer)?.[1],bytes:Number(/size (\d+)/.exec(pointer)?.[1])});
  }
  for(const row of large) {
   const pointer=pointers.get(entries.get(PROJECT+'/'+row.path));
   if(pointer.sha256!==row.sha256||pointer.bytes!==row.bytes)throw Error('Staged LFS asset differs from runtime snapshot: '+row.path);
  }
 }
 for(const row of rows.filter(row=>!usesLfs(row.path))) {
  const data=git(['cat-file','blob',entries.get(PROJECT+'/'+row.path)]);
  if(data.length!==row.bytes||crypto.createHash('sha256').update(data).digest('hex')!==row.sha256)throw Error('Staged asset differs from runtime snapshot: '+row.path);
 }
 console.log('RUNTIME INDEX PASS tracked='+entries.size+' assets/metadata='+required.length+' LFS='+large.length+' / references and production masters excluded');
 process.exit(0);
}

const listed=spawnSync(process.execPath,['tools/stage_release.mjs',`_work/clone-audit-${process.pid}`,'--list-inputs'],{encoding:'utf8',maxBuffer:16*1024*1024,env:{...process.env,CHIBI_NO_ORIGINAL_MEDIA:'0'}});
if(listed.status!==0)throw Error('Run git lfs pull and install the engine/templates before building.\n'+listed.stderr);
const inputs=JSON.parse(listed.stdout),binaries=new Set(inputs.filter(isBinaryAsset));
if(binaries.size!==rows.length||rows.some(row=>!binaries.has(row.path)))throw Error('Runtime snapshot differs from staging inputs; run node tools/runtime_assets.mjs --check');
for(const file of required) {
 if(!fs.existsSync(file))throw Error('Missing runtime asset/metadata; run git lfs pull: '+file);
 const size=fs.statSync(file).size;
 if(size<200&&fs.readFileSync(file,'utf8').startsWith('version https://git-lfs.github.com/spec/'))throw Error('Run git lfs pull: '+file);
}
for(const row of rows)if(fs.statSync(PROJECT+'/'+row.path).size!==row.bytes)throw Error('Runtime asset size changed: '+row.path);
console.log('RUNTIME INPUT PASS files='+inputs.length+' / runtime assets materialized; no production references required');
