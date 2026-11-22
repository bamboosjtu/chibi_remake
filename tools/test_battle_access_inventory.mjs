import assert from 'node:assert/strict';
import {collectReadModelUses} from './lib/battle_access_inventory.mjs';
const rows=collectReadModelUses({'presentation/battle/probe.gd':`# host.units
var label = "host.selected"
var a = host.map_data.units
var b = _ui.host.selected
var c = host.get('nav')
var d = host["units"]
var e = host.get.bind("map_data")
var f = host.decor_cells
var g = host.trainings
var ignored = "host.get('units')"
var indirect = host.get(variable)
`,'app/read_models/battle_queries.gd':'var provider = host.units'});
assert.deepEqual(rows.map(row=>[row.line,row.field]),[[3,'map_data'],[4,'selected'],[5,'nav'],[6,'units'],[7,'map_data'],[8,'decor_cells'],[9,'trainings']]);
assert(rows.every(row=>row.origin==='battle-access-host'));
const services=collectReadModelUses({'presentation/battle/probe.gd':`var a=host.visibility
var b=host.get.bind('clock')
var c=_ui.host.projectiles
var d=host["build_types"]
var e=host.task_events
`});
assert.deepEqual(services.map(row=>row.field),['visibility','clock','projectiles','build_types','task_events']);
const cursor=collectReadModelUses({'presentation/shell/software_cursor.gd':'var data = host.map_data'});
assert.equal(cursor[0].origin,'scene-facade');
console.log('BATTLE ACCESS INVENTORY NEGATIVE PASS comments / strings / provider excluded; literal lookup and scene facade distinguished');
