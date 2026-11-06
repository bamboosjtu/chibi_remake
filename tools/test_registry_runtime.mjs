import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),engine=path.resolve(args.includes('--engine')?args[args.indexOf('--engine')+1]:'Godot_v4.7.2-stable_win64.exe');
const directory=path.resolve('_work/registry-negative-runtime');fs.mkdirSync(directory,{recursive:true});
for(const [name,body] of Object.entries({
 missing:'var ports=preload("res://simulation/ports/abilities_dependencies.gd").new()\n\tpreload("res://composition_contract.gd").wire({},"negative",{"abilities":ports})',
 expired:'var port=preload("res://named_port.gd").new()\n\tvar value=RefCounted.new()\n\tvar reference=weakref(value)\n\tvalue=null\n\tport._require(reference,"expired")'
})){
 const file=path.join(directory,'named-'+name+'.gd');fs.writeFileSync(file,'extends SceneTree\nfunc _initialize() -> void:\n\t'+body+'\n');
 const result=await runGodot({engine,directory,name:'named-'+name,timeout:15,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',file]});
 assert.equal(result.code,1,result.output);assert(!result.timedOut);assert.match(result.output,/explicit port contract failed/);assert.doesNotMatch(result.output,/SCRIPT ERROR:|Parse Error:/);
}
console.log('REGISTRY RUNTIME NEGATIVE PASS missing provider / expired provider exit 1');
