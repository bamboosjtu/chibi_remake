import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),engine=path.resolve(args.includes('--engine')?args[args.indexOf('--engine')+1]:'Godot_v4.7.2-stable_win64.exe');
const directory=path.resolve('_work/registry-negative-runtime');fs.mkdirSync(directory,{recursive:true});
for(const [name,body] of Object.entries({
 missing:'var ports=preload("res://simulation/ports/abilities_dependencies.gd").new()\n\tpreload("res://composition_contract.gd").wire({},"negative",{"abilities":ports})',
 absent_call:'var port=preload("res://simulation/ports/technology_dependencies.gd").new()\n\tport._feedback("boom")',
 expired:'var port=preload("res://simulation/ports/technology_dependencies.gd").new()\n\tvar value=RefCounted.new()\n\tport._provider_battle_simulation=weakref(value)\n\tvalue=null\n\tport._feedback("boom")',
 command_missing:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tpreload("res://composition_contract.gd").wire({},"command negative",{"commands.technology":port})',
 command_method:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tvar value=RefCounted.new()\n\tpreload("res://composition_contract.gd").wire({"technology":value},"command negative",{"commands.technology":port})',
 command_expired:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tvar value=RefCounted.new()\n\tport._provider_technology=weakref(value)\n\tvalue=null\n\tif port.tech_is_sell(0): push_error("invalid fallback")',
 reader_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif reader.gold != 0: push_error("invalid fallback")\n\treader.free()'
})){
 const file=path.join(directory,'named-'+name+'.gd');fs.writeFileSync(file,'extends SceneTree\nfunc _initialize() -> void:\n\t'+body+'\n');
 const result=await runGodot({engine,directory,name:'named-'+name,timeout:15,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',file]});
 assert.equal(result.code,1,result.output);assert(!result.timedOut);assert.match(result.output,/explicit port contract failed/);assert.doesNotMatch(result.output,/SCRIPT ERROR:|Parse Error:/);
}
console.log('REGISTRY RUNTIME NEGATIVE PASS 7 cases: missing provider / missing method / actual absent and expired wrappers / expired read model; exit 1 without SCRIPT ERROR');
