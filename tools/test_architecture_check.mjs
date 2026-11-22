import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/layer-fixtures');fs.mkdirSync(parent,{recursive:true});const root=fs.mkdtempSync(path.join(parent,'case-'));
const write=(file,text)=>{fs.mkdirSync(path.dirname(path.join(root,file)),{recursive:true});fs.writeFileSync(path.join(root,file),text);};
const run=()=>spawnSync(process.execPath,['tools/architecture_check.mjs','--root',root],{encoding:'utf8'});
try{
 write('simulation/test.gd','extends RefCounted\n# load("res://app/ignored.gd")\n');assert.equal(run().status,0);
 for(const quote of ['"',"'"]){write('simulation/test.gd','extends RefCounted\nconst Bad = load('+quote+'res://app/upper.gd'+quote+')\n');assert.notEqual(run().status,0);}
 write('simulation/test.gd','extends RefCounted\n');
 for(const expression of ['FileAccess.open("rules.json", 1)', 'FileAccess.get_file_as_string("rules.json")', 'DirAccess.open(".")', 'JSON.parse_string("{}")', 'JSON.new()', 'ResourceLoader.load("rules.tres")', 'GDExtensionManager.load_extension("math.gdextension")', 'load("res://simulation/helper.gd")', 'OS.execute("reader", [])', 'Time.get_ticks_usec()', 'ProfileClock.now(true)']){
  write('simulation/test.gd','extends RefCounted\nfunc bad():\n\treturn '+expression+'\n');assert.notEqual(run().status,0,expression);
 }
 write('simulation/test.gd','extends RefCounted\n# FileAccess.open("ignored", 1)\nconst NOTE="JSON.parse_string and Time.get_ticks_usec() are forbidden"\nconst Valid=preload("res://simulation/helper.gd")\nfunc sample():\n\treturn ProfileClock.now(profile_enabled)\n');assert.equal(run().status,0);
 write('simulation/core/profile_clock.gd','extends RefCounted\nstatic func now(enabled):\n\treturn Time.get_ticks_usec()\n');assert.notEqual(run().status,0);
 write('simulation/core/profile_clock.gd','extends RefCounted\nstatic func now(enabled):\n\treturn Time.get_ticks_usec() if enabled else 0\n');assert.equal(run().status,0);
 write('simulation/test.gd','extends RefCounted\n');
 write('presentation/test.gd',"extends RefCounted\nconst Bad=preload('res://simulation/test.gd')\n");
 write('simulation/test.gd',"extends 'res://simulation/systems/mutable.gd'\nconst Indirect=load('res://simulation/systems/mutable.gd')\n");
 write('simulation/systems/mutable.gd','extends RefCounted\n');assert.notEqual(run().status,0);
 write('simulation/test.gd','extends RefCounted\n');write('presentation/test.gd','extends RefCounted\n');
 write('app/private.gd','extends RefCounted\nfunc bad(view):\n\treturn view._ui\n');assert.notEqual(run().status,0);
 write('app/private.gd','extends RefCounted\n');
 for (const value of ['Game.repository','host.world.combat._kill()', 'host.state.units', 'combat._damage()', 'host.actions._battle', 'load("res://app/automation/menu_driver.gd")']) {
  write('presentation/test.gd','extends RefCounted\nfunc bad(host):\n\treturn '+value+'\n');assert.notEqual(run().status,0,value);
 }
 write('presentation/test.gd','extends RefCounted\n');

 for(const mutation of ['tree.paused = false', 'get_tree().paused=true', 'tree.set("paused", false)', "tree.set_deferred('paused', true)"]){
  write('app/private.gd','extends RefCounted\nfunc bad(tree):\n\t'+mutation+'\n');assert.notEqual(run().status,0,mutation);
 }
 write('app/private.gd','extends RefCounted\n');
 write('app/battle/runtime/scene_controller.gd','extends RefCounted\nfunc _init(data: State, scene, node):\n\tpass\n');assert.notEqual(run().status,0);
 write('app/battle/runtime/scene_controller.gd','extends RefCounted\n');
 write('app/saves/save_service.gd','extends RefCounted\nfunc save(host):\n\thost.transports.reconcile()\n');assert.notEqual(run().status,0);
 write('app/saves/save_service.gd','extends RefCounted\n');
 write('app/campaign/campaign_session.gd','extends RefCounted\nfunc levels():\n\treturn FileAccess.open("map.json",1)\n');assert.notEqual(run().status,0);
 write('app/campaign/campaign_session.gd','extends RefCounted\n');
 write('app/saves/probe.gd','extends RefCounted\nfunc bad(view):\n\tview.unit_nodes({}).spr.visible=false\n');assert.notEqual(run().status,0);
 write('app/saves/probe.gd','extends RefCounted\n');
 write('app/read_models/unit_projection.gd','extends RefCounted\nfunc bad(unit):\n\treturn unit.duplicate(true)\n');assert.notEqual(run().status,0);
 write('app/read_models/unit_projection.gd','extends RefCounted\n');
 for(const field of ['units', 'selected', 'map_data', 'nav', 'decor_cells', 'trainings', 'visibility', 'clock', 'projectiles', 'fire_fields', 'player_commands', 'build_types', 'cmd_pending_data', 'task_events', 'terrain_changes']){
  write('presentation/battle/units/unit_visuals.gd','extends RefCounted\nfunc bad(host):\n\treturn host.'+field+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/units/unit_visuals.gd','extends RefCounted\n');
 write('app/private.gd','extends RefCounted\nfunc bad(world):\n\tworld._modules.clear()\n');assert.notEqual(run().status,0);
 write('app/private.gd','extends RefCounted\n');
 write('presentation/battle/camera/camera_controller.gd','extends RefCounted\nfunc bad(host):\n\treturn host.units\n');assert.notEqual(run().status,0);
 write('presentation/battle/camera/camera_controller.gd','extends RefCounted\n');
 for(const read of ['host.units','host.selected','host.map_data','host.nav',"host.get('nav')",'host["units"]']){
  write('presentation/battle/world/build_preview.gd','extends RefCounted\nfunc bad(host):\n\treturn '+read+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/world/build_preview.gd','extends RefCounted\n');
 for(const read of ['host.map_data','host.nav','host.decor_cells',"host.get('decor_cells')",'host["map_data"]']){
  write('presentation/battle/world/battle_resources.gd','extends RefCounted\nfunc bad(host):\n\treturn '+read+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/world/battle_resources.gd','extends RefCounted\n');

 for(const field of ['units','selected','map_data','decor_cells']){
  write('app/read_models/battle_queries.gd','extends RefCounted\nfunc bad(data):\n\treturn data.'+field+'.duplicate(true)\n');assert.notEqual(run().status,0);
 }
 write('app/read_models/battle_queries.gd','extends RefCounted\n');
 write('presentation/test.gd','extends RefCounted\nfunc bad(host):\n\thost.saver.apply_snapshot({})\n');assert.notEqual(run().status,0);
 write('presentation/test.gd','extends RefCounted\n');
 // An Object subclass must be created by a composition point that frees it.
 write('simulation/unowned.gd','extends Object\n');
 write('simulation/creator.gd','extends RefCounted\nconst Made=preload("res://simulation/unowned.gd")\nfunc make():\n\treturn Made.new()\n');
 assert.notEqual(run().status,0,'Object subclass without an owning release point');
 write('simulation/creator.gd','extends RefCounted\nconst Made=preload("res://simulation/unowned.gd")\nfunc make():\n\tvar value=Made.new()\n\tvalue.free()\n');
 assert.equal(run().status,0);
 write('simulation/unowned.gd','extends RefCounted\n');
 write('simulation/creator.gd','extends RefCounted\n');
 const limits={files:{'simulation/test.gd':600},functions:{},violations:[],reviews:{}};
 const checkReview=()=>{write('limits.json',JSON.stringify(limits));return spawnSync(process.execPath,['tools/architecture_check.mjs','--root',root,'--limits',path.join(root,'limits.json')],{encoding:'utf8'});};
 assert.notEqual(checkReview().status,0,'Waivers require ownership and a deadline');
 limits.reviews['files:simulation/test.gd']={owner:'project-maintainers',reason:'fixture',reviewBy:'2000-01-01'};
 assert.notEqual(checkReview().status,0,'Expired waivers must fail');
 limits.reviews['files:simulation/test.gd'].reviewBy='2099-02-31';assert.notEqual(checkReview().status,0,'Invalid calendar date');
 limits.reviews['files:simulation/test.gd'].reviewBy='2099-02-28';assert.equal(checkReview().status,0);
 console.log('ARCHITECTURE NEGATIVE PASS both quote styles / dynamic literal load / transitive mutable dependency / simulation I/O and opt-in profiling / comments and strings ignored');
}finally{assert.equal(path.dirname(root),parent);fs.rmSync(root,{recursive:true,force:true});}
