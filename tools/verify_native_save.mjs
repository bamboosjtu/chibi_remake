import fs from 'node:fs';import path from 'node:path';import {spawn} from 'node:child_process';import crypto from 'node:crypto';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const exe=path.resolve(option('--exe')),directory=path.resolve(option('--output','_work/native-save'));
fs.mkdirSync(directory,{recursive:true});const results=[];
for(const mode of ['green','system']){
 const testId=crypto.randomUUID(),profile=path.join(directory,'system-profile');fs.mkdirSync(profile,{recursive:true});
 for(const phase of ['write','read']){
  const name='native-save-'+mode+'-'+phase;
  const userArgs=['--map=chibil1','--no-intro','--view','--native-save='+phase,'--save-test-id='+testId,...(mode==='system'?['--storage-mode=system']:[])];
  const env=mode==='system'?{...process.env,APPDATA:profile,LOCALAPPDATA:profile}:process.env;
  let output='',timedOut=false;
  const child=spawn(exe,['--headless','--',...userArgs],{windowsHide:true,env});
  child.stdout.on('data',b=>{output+=b;});child.stderr.on('data',b=>{output+=b;});
  const timer=setTimeout(()=>{timedOut=true;child.kill();},120000);
  const code=await new Promise((resolve,reject)=>{child.on('close',resolve);child.on('error',reject);}).finally(()=>clearTimeout(timer));
  const log=path.join(directory,name+'.log');fs.writeFileSync(log,output);
  const marker='NATIVE SAVE ACCEPTANCE PASS '+phase;
  const missing=output.includes(marker)?[]:[marker];
  const ok=code===0&&!timedOut&&!missing.length&&!/SCRIPT ERROR:|NATIVE (?:SAVE|LOAD|AUTO SAVE) FAIL/.test(output);
  results.push({name,ok,code,timedOut,missing,log});fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');
  console.log(`${ok?'PASS':'FAIL'} ${name} ${log}`);
  if(!ok)process.exit(1);
 }
}
