import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),i=args.indexOf('--engine'),engine=path.resolve(i>=0?args[i+1]:'Godot_v4.7.2-stable_win64.exe');
const result=await runGodot({engine,directory:path.resolve('_work/startup-load-safety'),name:'once-only',timeout:100,markers:['RESTORE SAFETY PASS'],args:['--headless','--resolution','1920x1080','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_restore_safety.gd'),'--','--noview','--no-intro','--map=chibil1','--load','--save-test-id=startup-load']});
assert(result.ok,result.output);console.log('STARTUP LOAD SAFETY PASS map/load args consumed once / rejected load remains at menu / automatic slot unchanged');
