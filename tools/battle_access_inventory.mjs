import fs from 'node:fs';
import {collectReadModelUses} from './lib/battle_access_inventory.mjs';
const root='godot/chibi_remake';
const walk=dir=>fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(dir+'/'+entry.name):entry.name.endsWith('.gd')?[dir+'/'+entry.name]:[]);
const sources=Object.fromEntries(walk(root+'/presentation').map(file=>[file.slice(root.length+1),fs.readFileSync(file,'utf8')]));
const references=collectReadModelUses(sources);
const consumers=[...new Set(references.map(row=>row.file))].map(file=>({file,
  origin:references.find(row=>row.file===file).origin,
  fields:Object.fromEntries(['units','selected','map_data','nav','decor_cells','trainings'].map(field=>[field,references.filter(row=>row.file===file&&row.field===field).length]))}));
const report={schemaVersion:3,method:'Literal host/_ui.host properties and literal get/index lookups; excludes the provider. Six retired collection/navigation getters are guarded across presentation. Aliases, dynamic keys and command-returned dictionaries require manual review; stateful service capabilities remain a separate migration surface. Host origins are reviewed conventions, not inferred types.',
  guardedScope:'All presentation scripts except the provider',
  migratedConsumers:['presentation/battle/components/camera_controller.gd', 'presentation/battle/build_preview.gd', 'presentation/battle/battle_resources.gd', 'presentation/battle/battle_minimap.gd', 'presentation/battle/components/command_art.gd', 'presentation/battle/components/command_model.gd', 'presentation/battle/components/selection_info.gd', 'presentation/battle/components/unit_visuals.gd', 'presentation/battle/components/hud_input.gd', 'presentation/battle/projectile_view.gd', 'presentation/battle/terrain_stream.gd', 'presentation/hud/battle_hud_panel.gd', 'presentation/hud/software_cursor.gd'],
  references,consumers};
const target='tools/inputs/battle_access_inventory.json',text=JSON.stringify(report,null,2)+'\n';
if(process.argv.includes('--write'))fs.writeFileSync(target,text);
else if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==text)throw Error('BattleAccess inventory stale; review and run node tools/battle_access_inventory.mjs --write');
console.log(`BATTLE ACCESS INVENTORY PASS ${references.length} literal access sites / ${consumers.length} consumers / explicit scope limitations`);
