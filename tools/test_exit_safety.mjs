import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),index=args.indexOf('--engine'),engine=path.resolve(index>=0?args[index+1]:'Godot_v4.7.2-stable_win64.exe');
for(const mode of ['victory','defeat','failure','uninitialized']){
 const result=await runGodot({engine,directory:path.resolve('_work/exit-safety'),name:mode,timeout:45,markers:['EXIT SAFETY PASS '+mode],args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_exit_safety.gd'),'--','--no-intro','--exit-case='+mode,'--save-test-id=exit-'+mode]});
 assert(result.ok,result.output);
 console.log('EXIT SAFETY PASS '+mode);
}
