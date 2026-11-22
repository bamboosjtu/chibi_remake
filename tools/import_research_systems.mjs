import fs from 'node:fs';
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const write=(name,value)=>fs.writeFileSync('godot/chibi_remake/data/db/'+name,JSON.stringify(value,null,2)+'\n');
write('command_variants.json',read('research/50-commands/data/panel_variants.json'));
write('startup_briefings.json',read('research/10-startup/data/startup_texts.json'));
const exp=read('research/20-exp-level/data/exp_level.json');
write('officer_progression.json',{schemaVersion:1,source:exp.source,thresholds:exp.thresholds,levelCap:exp.level_cap,levelUp:exp.level_up,gradeTable:exp.stat_effects.grade_table,rewards:read('research/20-exp-level/data/kill_xp.json').types});
console.log('Imported selection variants, 34 briefings, and officer progression rules.');
