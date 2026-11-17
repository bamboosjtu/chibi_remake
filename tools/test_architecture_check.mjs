import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/layer-fixtures');fs.mkdirSync(parent,{recursive:true});const root=fs.mkdtempSync(path.join(parent,'case-'));
const write=(file,text)=>{fs.mkdirSync(path.dirname(path.join(root,file)),{recursive:true});fs.writeFileSync(path.join(root,file),text);};
const run=()=>spawnSync(process.execPath,['tools/architecture_check.mjs','--root',root],{encoding:'utf8'});
try{
 write('simulation/test.gd','extends RefCounted\n# load("res://app/ignored.gd")\n');assert.equal(run().status,0);
 for(const quote of ['"',"'"]){write('simulation/test.gd','extends RefCounted\nconst Bad = load('+quote+'res://app/upper.gd'+quote+')\n');assert.notEqual(run().status,0);}
 write('simulation/test.gd','extends RefCounted\n');
 write('presentation/test.gd',"extends RefCounted\nconst Bad=preload('res://simulation/test.gd')\n");
 write('simulation/test.gd',"extends 'res://named_port.gd'\nconst Indirect=load('res://simulation/systems/mutable.gd')\n");
 write('simulation/systems/mutable.gd','extends RefCounted\n');assert.notEqual(run().status,0);
 write('simulation/test.gd','extends RefCounted\n');write('presentation/test.gd','extends RefCounted\n');
 write('app/private.gd','extends RefCounted\nfunc bad(view):\n\treturn view._ui\n');assert.notEqual(run().status,0);
 write('app/private.gd','extends RefCounted\n');
 write('app/saves/probe.gd','extends RefCounted\nfunc bad(view):\n\tview.unit_nodes({}).spr.visible=false\n');assert.notEqual(run().status,0);
 write('app/saves/probe.gd','extends RefCounted\n');
 write('app/read_models/unit_projection.gd','extends RefCounted\nfunc bad(unit):\n\treturn unit.duplicate(true)\n');assert.notEqual(run().status,0);
 write('app/read_models/unit_projection.gd','extends RefCounted\n');
 for(const field of ['units','selected','map_data','nav','trainings']){
  write('presentation/battle/components/unit_visuals.gd','extends RefCounted\nfunc bad(host):\n\treturn host.'+field+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/components/unit_visuals.gd','extends RefCounted\n');
 write('app/private.gd','extends RefCounted\nfunc bad(world):\n\tworld._modules.clear()\n');assert.notEqual(run().status,0);
 write('app/private.gd','extends RefCounted\n');
 write('presentation/battle/components/camera_controller.gd','extends RefCounted\nfunc bad(host):\n\treturn host.units\n');assert.notEqual(run().status,0);
 write('presentation/battle/components/camera_controller.gd','extends RefCounted\n');
 for(const read of ['host.units','host.selected','host.map_data','host.nav',"host.get('nav')",'host["units"]']){
  write('presentation/battle/build_preview.gd','extends RefCounted\nfunc bad(host):\n\treturn '+read+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/build_preview.gd','extends RefCounted\n');
 for(const read of ['host.map_data','host.nav','host.decor_cells',"host.get('decor_cells')",'host["map_data"]']){
  write('presentation/battle/battle_resources.gd','extends RefCounted\nfunc bad(host):\n\treturn '+read+'\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/battle_resources.gd','extends RefCounted\n');

 for(const field of ['units','selected','map_data','decor_cells']){
  write('presentation/battle/battle_access.gd','extends RefCounted\nfunc bad(data):\n\treturn data.'+field+'.duplicate(true)\n');assert.notEqual(run().status,0);
 }
 write('presentation/battle/battle_access.gd','extends RefCounted\n');
 write('presentation/test.gd','extends RefCounted\nfunc bad(host):\n\thost.saver.apply_snapshot({})\n');assert.notEqual(run().status,0);
 write('presentation/test.gd','extends RefCounted\n');
 const limits={files:{'simulation/test.gd':600},functions:{},violations:[],reviews:{}};
 const checkReview=()=>{write('limits.json',JSON.stringify(limits));return spawnSync(process.execPath,['tools/architecture_check.mjs','--root',root,'--limits',path.join(root,'limits.json')],{encoding:'utf8'});};
 assert.notEqual(checkReview().status,0,'Waivers require ownership and a deadline');
 limits.reviews['files:simulation/test.gd']={owner:'project-maintainers',reason:'fixture',reviewBy:'2000-01-01'};
 assert.notEqual(checkReview().status,0,'Expired waivers must fail');
 limits.reviews['files:simulation/test.gd'].reviewBy='2099-02-31';assert.notEqual(checkReview().status,0,'Invalid calendar date');
 limits.reviews['files:simulation/test.gd'].reviewBy='2099-02-28';assert.equal(checkReview().status,0);
 console.log('ARCHITECTURE NEGATIVE PASS both quote styles / dynamic literal load / transitive mutable dependency / commented imports ignored');
}finally{assert.equal(path.dirname(root),parent);fs.rmSync(root,{recursive:true,force:true});}
