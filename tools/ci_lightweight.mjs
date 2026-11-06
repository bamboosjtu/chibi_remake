import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
function walk(dir) {return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(dir+'/'+e.name):[dir+'/'+e.name]);}
for(const file of walk('tools').filter(f=>f.endsWith('.mjs'))) {
 const r=spawnSync(process.execPath,['--check',file],{stdio:'inherit'});if(r.status!==0)process.exit(1);
}
for(const file of walk('godot/chibi_remake/data/db').filter(f=>f.endsWith('.json')))JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
for(const file of ['LICENSE','NOTICE.md','docs/20-legal.md'])if(!fs.statSync(file).size)throw Error(file);
const scripts=new Set();for(const test of ['release_tests','development_tests','known_failures'].flatMap(name=>JSON.parse(fs.readFileSync('tools/inputs/'+name+'.json')).tests)){
 if(scripts.has(test.script)||!test.markers.length||!fs.existsSync('tools/gd/'+test.script+'.gd'))throw Error(test.script);scripts.add(test.script);
}
for (const script of ['tools/docs_lint.mjs','tools/data_check.mjs','tools/test_bootstrap.mjs','tools/test_repository_policy.mjs','tools/architecture_check.mjs','tools/registry_check.mjs','tools/test_registry_check.mjs','tools/powershell_encoding.mjs','tools/test_powershell_encoding.mjs','tools/test_map_export_navigation.mjs','tools/test_godot_process.mjs','tools/test_regression_result.mjs','tools/test_terrain_dedup.mjs']) { const r=spawnSync(process.execPath,[script],{stdio:'inherit'});if(r.status!==0)process.exit(1); }
for(const args of [['tools/compare_terrain_rebuild.mjs','--declarations'],['tools/test_terrain_equivalence.mjs']]){const r=spawnSync(process.execPath,args,{stdio:'inherit'});if(r.status!==0)process.exit(1);}
console.log('LIGHTWEIGHT CI PASS JavaScript syntax / DB JSON / notices / release suite contracts');
