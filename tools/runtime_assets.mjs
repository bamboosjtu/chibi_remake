import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {PROJECT,SNAPSHOT,collectAssets,readAssets,ignoreAllowlist} from './lib/runtime_assets.mjs';

const args=process.argv.slice(2),write=args.includes('--write'),hash=args.includes('--hash');
const versionedOnly=!write&&args.includes('--versioned-only');
const sourceCi=!write&&args.includes('--source-ci');
if(!write&&!args.includes('--check'))throw Error('Usage: node tools/runtime_assets.mjs --write | --check [--hash]');
let expected;
if(!versionedOnly){
 const listed=spawnSync(process.execPath,['tools/stage_release.mjs','_work/runtime-assets-'+process.pid,'--list-inputs',
  ...(sourceCi?['--omit-generated-terrain']:[]),'--omit-videos'],{encoding:'utf8',maxBuffer:16*1024*1024});
 if(listed.status!==0)throw Error(listed.stderr);
 expected=collectAssets(JSON.parse(listed.stdout));
}
if(write) {
 const lines=[];let bytes=0;
 for(const [i,row] of expected.entries()) {
  const data=fs.readFileSync(PROJECT+'/'+row.path);
  lines.push([crypto.createHash('sha256').update(data).digest('hex'),data.length,row.path,...(row.metadata.length?[row.metadata.join(',')]:[])].join('\t'));
  bytes+=data.length;
  if((i+1)%10000===0)console.log('Runtime assets hashed: '+(i+1)+'/'+expected.length);
 }
 fs.writeFileSync(SNAPSHOT,lines.join('\n')+'\n');
 const rules=fs.readFileSync('.gitignore','utf8').replaceAll('\r\n','\n').replaceAll('\r','').replace(/\n?# BEGIN RUNTIME ASSETS[\s\S]*?# END RUNTIME ASSETS\n?/,'').trimEnd();
 fs.writeFileSync('.gitignore',rules+'\n\n'+ignoreAllowlist(expected)+'\n');
 console.log('RUNTIME ASSETS WRITE files='+expected.length+' GiB='+(bytes/2**30).toFixed(3));
} else {
 const all=readAssets(),rows=all;
 if(!versionedOnly&&JSON.stringify(rows.map(({path,metadata})=>({path,metadata})))!==JSON.stringify(expected))throw Error('Runtime assets changed; review and run node tools/runtime_assets.mjs --write');
 for(const row of rows) {
  const file=PROJECT+'/'+row.path;
  if(fs.statSync(file).size!==row.bytes)throw Error('Runtime asset size changed: '+row.path);
  if(hash&&crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')!==row.sha256)throw Error('Runtime asset hash changed: '+row.path);
 }
 const ignoreText=fs.readFileSync('.gitignore','utf8').replace(/\r\n/g,'\n');
 if(!ignoreText.includes(ignoreAllowlist(all)))throw Error('Runtime asset allowlist is stale');
 console.log((versionedOnly?'VERSIONED RUNTIME ASSETS PASS ':'RUNTIME ASSETS PASS ')+'files='+rows.length+(hash?' / sha256':' / size')+(versionedOnly?' / declared versioned blobs; generated terrain/staging validation is separate':' / exact staging inputs; production references excluded'));
}
