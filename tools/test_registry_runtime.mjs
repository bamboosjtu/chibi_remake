import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {runGodot} from './lib/godot_process.mjs';
const args=process.argv.slice(2),engine=path.resolve(args.includes('--engine')?args[args.indexOf('--engine')+1]:'Godot_v4.7.2-stable_win64.exe');
const directory=path.resolve(args.includes('--output')?args[args.indexOf('--output')+1]:'_work/registry-negative-runtime');fs.mkdirSync(directory,{recursive:true});
for(const [name,body] of Object.entries({
 missing:'preload("res://composition_contract.gd").wire({"combat":null},"negative")',
 missing_peer:'var module=preload("res://simulation/units/unit_actions.gd").new(preload("res://simulation/state/battle_state.gd").new())\n\tpreload("res://composition_contract.gd").wire({"unit_actions":module},"negative")',
 wrong_peer:'var nav=preload("res://simulation/navigation/nav.gd").new()\n\tvar other=preload("res://simulation/navigation/nav.gd").new()\n\tpreload("res://composition_contract.gd").wire({"paths":nav.paths,"grid":other.grid},"wrong navigation grid")',
 unknown_visual:'var battle=load("res://main.gd").new()\n\tvar view=Node2D.new()\n\tbattle.scene.view=view\n\tbattle._on_visual("unknown_visual",[])\n\tbattle.dispose_services()\n\tview.free()\n\tbattle.free()',
 unknown_sound:'var battle=load("res://main.gd").new()\n\tvar sound=Node.new()\n\tbattle.scene.sfx=sound\n\tbattle._on_sound("unknown_sound",[])\n\tbattle.dispose_services()\n\tsound.free()\n\tbattle.free()',
 unknown_state:'var nav=preload("res://simulation/navigation/nav.gd").new()\n\tnav.get("misspelled_field")',
 // A read model outlives its host during teardown. Each query must return the empty
 // value of its own type and report the contract failure once, never dereference.
 expired_unit_views:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.unit_views().is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_visual:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.visual_unit(0).is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_selection:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.selection_views().is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_production:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.training_views().is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_work:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.building_work(0).is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_motion:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.motion_views().is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_visibility:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.visibility_view().is_empty())\n\tprint("PROBE caller continued after guarded return")',
 expired_pointer:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(not reader.cursor_targets(Vector2.ZERO,"attack").attack)\n\tassert(not reader.point_visible(Vector2.ZERO))\n\tprint("PROBE caller continued after guarded return")',
 expired_scalars:'var host=Node2D.new()\n\tvar reader=preload("res://app/read_models/battle_queries.gd").new(host)\n\thost.free()\n\tassert(reader.world_identity()==-1 and reader.sim_tick==0 and reader.map_caption()=="" and reader.renderable_unit_count()==0)\n\tprint("PROBE caller continued after guarded return")'
})){
 const file=path.join(directory,'named-'+name+'.gd');fs.writeFileSync(file,'extends SceneTree\nfunc _initialize() -> void:\n\t_probe.call_deferred()\nfunc _probe() -> void:\n\t'+body+'\n');
 const result=await runGodot({engine,directory,name:'named-'+name,timeout:15,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',file]});
 assert.equal(result.code,1,result.output);assert(!result.timedOut);assert.match(result.output,/contract validation failed/);assert.doesNotMatch(result.output,/SCRIPT ERROR:|Parse Error:/);
 assert.match(result.output,/shutdown requested \(exit 1\)/);
}
console.log('REGISTRY RUNTIME NEGATIVE PASS missing service, wrong peer, invalid events and expired read models');
const releasePolicy=await runGodot({engine,directory,name:'presentation-release-policy',timeout:30,args:['--headless','--path',path.resolve('godot/chibi_remake'),'--script',path.resolve('tools/gd/test_presentation_diagnostics.gd')],markers:['PRESENTATION DIAGNOSTICS PASS']});
assert(releasePolicy.ok,releasePolicy.output);
assert.doesNotMatch(releasePolicy.output,/contract validation failed/);
assert.equal((releasePolicy.output.match(/Unhandled presentation event dropped:/g)||[]).length,2,releasePolicy.output);
assert.equal((releasePolicy.output.match(/Unhandled presentation events at battle end:/g)||[]).length,1,releasePolicy.output);
console.log('PRESENTATION RUNTIME PASS release policy survives / per-verb warnings / exactly one counted end summary');
