import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import os from 'node:os';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const directory=path.resolve(option('--output','_work/bench/hot-paths')),engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe'));
fs.mkdirSync(directory,{recursive:true});
const budgets=JSON.parse(fs.readFileSync('tools/inputs/hot_path_budgets.json','utf8'));
function command(binary,args){const r=spawnSync(binary,args,{encoding:'utf8',maxBuffer:16*1024*1024});if(r.status!==0)throw Error(r.stderr||r.stdout||String(r.error));return r.stdout.trim();}
async function run(name,project){
 const r=await runGodot({engine,directory,name,timeout:300,markers:['HOT PATH BENCHMARK PASS'],args:['--headless','--path',project,'--script',path.resolve('tools/gd/bench_hot_paths.gd'),'--','--noview','--no-intro','--save-test-id=hot-'+crypto.randomUUID()]});
 assert(r.ok,r.output);return {log:r.log,metrics:JSON.parse(r.output.match(/^HOT PATH BENCHMARK JSON: (.+)$/m)[1])};
}
const report={schemaVersion:1,baseline:null,current:null,budgets};
if(args.includes('--baseline')){
 const revision=command('git',['rev-parse',option('--baseline')+'^{commit}']);
 // A unique archive contains historical source and catalogs. Materialize only
 // exact LFS identities from the working tree, without changing original assets.
 const fixture=fs.mkdtempSync(path.join(directory,'baseline-')),archive=path.join(fixture,'source.tar');
 command('git',['archive','--format=tar','-o',archive,revision+':godot/chibi_remake']);
 const project=path.join(fixture,'project');fs.mkdirSync(project);command('tar',['-xf',archive,'-C',project]);
 const files=dir=>fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);
 for(const file of files(project))if(fs.statSync(file).size<256){
  const pointer=fs.readFileSync(file,'utf8').match(/^version https:\/\/git-lfs.github.com\/spec\/v1\r?\noid sha256:([a-f0-9]{64})\r?\nsize (\d+)/);
  if(!pointer)continue;
  const source=path.resolve('godot/chibi_remake',path.relative(project,file));
  if(!fs.existsSync(source))continue;
  const bytes=fs.readFileSync(source);if(crypto.createHash('sha256').update(bytes).digest('hex')!==pointer[1])continue;
  fs.unlinkSync(file);try{fs.linkSync(source,file);}catch{fs.copyFileSync(source,file);}
  if(/\.(?:otf|ttf)$/.test(file) && fs.existsSync(source+'.import')){
   const imported=fs.readFileSync(source+'.import','utf8').match(/^path="res:\/\/(.+)"/m)?.[1];
   if(imported && fs.existsSync(path.resolve('godot/chibi_remake',imported))){
    const target=path.join(project,imported);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.resolve('godot/chibi_remake',imported),target);
   }
  }
 }
 report.baseline={revision,...await run('before',project)};
}
report.current=await run('current',path.resolve('godot/chibi_remake'));
for(const [name,max] of Object.entries(budgets.p95Ms))assert(report.current.metrics[name].p95Ms<=max,`${name} P95 exceeds ${max}ms`);
assert(report.current.metrics.blockedDestination.queriesPerInvocation<=budgets.blockedQueriesPerInvocation);
if(report.baseline){
 assert.deepEqual(report.current.metrics.forest8Workers.signature,report.baseline.metrics.forest8Workers.signature,'Resource target/path order changed');
 report.p95Change=Object.fromEntries(Object.keys(budgets.p95Ms).map(name=>[name,{before:report.baseline.metrics[name].p95Ms,after:report.current.metrics[name].p95Ms}]));
}
const harnessFiles=['tools/gd/bench_hot_paths.gd','tools/gd/test_contact_and_occupancy.gd','tools/lib/godot_process.mjs','tools/inputs/hot_path_budgets.json',import.meta.filename];
report.harnessHash=crypto.createHash('sha256').update(Buffer.concat(harnessFiles.map(file=>fs.readFileSync(file)))).digest('hex');
report.engineHash=crypto.createHash('sha256').update(fs.readFileSync(engine)).digest('hex');
report.sourceRulesManifestHash=crypto.createHash('sha256').update(fs.readFileSync('godot/chibi_remake/data/db/rules_manifest.json')).digest('hex');
report.sourceRulesIdentityHash=crypto.createHash('sha256').update(fs.readFileSync('godot/chibi_remake/app/saves/rules_identity.gd')).digest('hex');
report.machine={cpu:os.cpus()[0]?.model,logicalCpus:os.cpus().length,platform:os.platform(),release:os.release(),arch:os.arch()};
fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(report,null,2)+'\n');
console.log('HOT PATHS PASS '+JSON.stringify(report.p95Change??report.current.metrics));
