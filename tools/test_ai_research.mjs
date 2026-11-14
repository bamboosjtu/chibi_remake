import path from 'node:path';
import fs from 'node:fs';
import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const directory=path.resolve(option('--output','_work/ai-research'));
const result=await runGodot({engine:path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe')),directory,name:'research',timeout:240,markers:['AI RESEARCH PASS'],args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_ai_research.gd'),'--','--noview','--no-intro','--save-test-id=ai-research']});
const {output,...summary}=result;fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify(summary));if(!result.ok){console.error(output.slice(-6000));process.exitCode=1;}
