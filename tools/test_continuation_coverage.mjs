import path from 'node:path';import fs from 'node:fs';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe')),directory=path.resolve(option('--output','_work/continuation-coverage'));
const results=[];
const maps=['chibic1','chibil1','chibic10','chibic17'];
const selected=option('--map',null);if(selected&&!maps.includes(selected))throw Error('Unknown representative map');
for(const map of selected?[selected]:maps){
 const result=await runGodot({engine,directory,name:map,timeout:600,markers:['CONTINUATION COVERAGE PASS'],args:['--headless','--resolution','1920x1080','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_continuation_coverage.gd'),'--','--no-intro','--noview','--coverage-map='+map,'--save-test-id=continuation-'+map]});
 const {output,...summary}=result;results.push(summary);fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(results,null,2)+'\n');console.log((result.ok?'PASS':'FAIL')+' continuation '+map+' '+result.seconds+'s');
 if(!result.ok){console.error(result.output.slice(-5000));process.exit(1);}
}
console.log('FULL CONTINUATION PASS selected representative maps / 15s and 60s / six checkpoints each / AI and navigation caches');
