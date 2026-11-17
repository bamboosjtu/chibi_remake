import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),engine=path.resolve(args.includes('--engine')?args[args.indexOf('--engine')+1]:'Godot_v4.7.2-stable_win64.exe');
const directory=path.resolve(args.includes('--output')?args[args.indexOf('--output')+1]:'_work/registry-negative-runtime');fs.mkdirSync(directory,{recursive:true});
for(const [name,body] of Object.entries({
 missing:'var ports=preload("res://simulation/service_dependencies.gd").new({"combat":["_kill"]})\n\tpreload("res://composition_contract.gd").wire({},"negative",{"abilities":ports})',
 absent_call:'var port=preload("res://app/battle/ports/scene_controller_dependencies.gd").new()\n\tport._feedback("boom")\n\tprint("PROBE caller continued after guarded return")',
 expired:'var port=preload("res://app/battle/ports/scene_controller_dependencies.gd").new()\n\tvar value=RefCounted.new()\n\tport._provider_battle_simulation=weakref(value)\n\tvalue=null\n\tport._feedback("boom")\n\tprint("PROBE caller continued after guarded return")',
 scope_absent:'var port=preload("res://simulation/service_dependencies.gd").new({"battle_simulation":["_feedback"]})\n\tassert(port.acquire(["battle_simulation"]).is_empty())\n\tprint("PROBE caller continued after guarded return")',
 scope_expired:'var port=preload("res://simulation/service_dependencies.gd").new({"battle_simulation":["_feedback"]})\n\tvar value=RefCounted.new()\n\tport._references["battle_simulation"]=weakref(value)\n\tvalue=null\n\tassert(port.acquire(["battle_simulation"]).is_empty())\n\tprint("PROBE caller continued after guarded return")',
 unit_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.unit_views().is_empty())\n\treader.free()',
 visual_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.visual_unit(0).is_empty())\n\treader.free()',
 selection_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.selection_views().is_empty())\n\treader.free()',
 production_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.training_views().is_empty())\n\treader.free()',
 work_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.building_work(0).is_empty())\n\treader.free()',
 cursor_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.cursor_targets(Vector2.ZERO,"attack").is_empty())\n\treader.free()',
 motion_values_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tassert(reader.motion_views().is_empty())\n\treader.free()',
 command_missing:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tpreload("res://composition_contract.gd").wire({},"command negative",{"commands.technology":port})',
 command_method:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tvar value=RefCounted.new()\n\tpreload("res://composition_contract.gd").wire({"technology":value},"command negative",{"commands.technology":port})',
 command_expired:'var port=preload("res://app/commands/technology_commands.gd").new()\n\tvar value=RefCounted.new()\n\tport._provider_technology=weakref(value)\n\tvalue=null\n\tif port.tech_is_sell(0): push_error("invalid fallback")',
 reader_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif reader.gold != 0: push_error("invalid fallback")\n\treader.free()',
 preview_key_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif not reader.construction_preview_key(Vector2.ZERO).is_empty(): push_error("invalid fallback")\n\treader.free()',
 preview_model_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif not reader.construction_preview_at(Vector2.ZERO).is_empty(): push_error("invalid fallback")\n\treader.free()',
 resource_key_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif not reader.resource_layer_key(Rect2()).is_empty(): push_error("invalid fallback")\n\treader.free()',
 resource_projection_expired:'var data=Node2D.new()\n\tvar reader=preload("res://presentation/battle/battle_access.gd").new(data,RefCounted.new(),RefCounted.new())\n\tdata.free()\n\tif not reader.resource_layer_projection(Rect2()).is_empty(): push_error("invalid fallback")\n\treader.free()',
 unknown_visual:'var battle=load("res://main.gd").new()\n\tvar view=Node2D.new()\n\tbattle.scene.view=view\n\tbattle._on_visual("unknown_visual",[])\n\tbattle.dispose_services()\n\tview.free()\n\tbattle.free()',
 unknown_sound:'var battle=load("res://main.gd").new()\n\tvar sound=Node.new()\n\tbattle.scene.sfx=sound\n\tbattle._on_sound("unknown_sound",[])\n\tbattle.dispose_services()\n\tsound.free()\n\tbattle.free()',
 unknown_state:'var nav=preload("res://simulation/navigation/nav.gd").new()\n\tnav.get("misspelled_field")'
})){
 const file=path.join(directory,'named-'+name+'.gd');fs.writeFileSync(file,'extends SceneTree\nfunc _initialize() -> void:\n\t_probe.call_deferred()\nfunc _probe() -> void:\n\t'+body+'\n');
 const result=await runGodot({engine,directory,name:'named-'+name,timeout:15,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',file]});
 assert.equal(result.code,1,result.output);assert(!result.timedOut);assert.match(result.output,/explicit port contract failed/);assert.doesNotMatch(result.output,/SCRIPT ERROR:|Parse Error:/);
 assert.match(result.output,/shutdown requested \(exit 1\); current frame continues with defaults/);
 if(['absent_call','expired','scope_absent','scope_expired'].includes(name))assert.match(result.output,/PROBE caller continued after guarded return/);
}
console.log('REGISTRY RUNTIME NEGATIVE PASS 23 cases: missing provider / missing method / expired scopes, wrappers and read model / unknown debug events and state property; exit 1 without SCRIPT ERROR');
const releasePolicy=await runGodot({engine,directory,name:'presentation-release-policy',timeout:30,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_presentation_diagnostics.gd')],markers:['PRESENTATION DIAGNOSTICS PASS']});
assert(releasePolicy.ok,releasePolicy.output);
assert.doesNotMatch(releasePolicy.output,/explicit port contract failed/);
assert.equal((releasePolicy.output.match(/Unhandled presentation event dropped:/g)||[]).length,2,releasePolicy.output);
assert.equal((releasePolicy.output.match(/Unhandled presentation events at battle end:/g)||[]).length,1,releasePolicy.output);
console.log('PRESENTATION RUNTIME PASS release policy survives / per-verb warnings / exactly one counted end summary');
