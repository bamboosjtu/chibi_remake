import fs from 'node:fs';
const root = 'godot/chibi_remake';
const schema = fs.readFileSync(root+'/simulation/units/unit_schema.gd','utf8');
const declared = new Set([...schema.matchAll(/^\s*"(\w+)": \{/gm)].map(match => match[1]));
const factory = fs.readFileSync(root+'/simulation/units/entity_factory.gd','utf8');
const record = factory.match(/var u := \{[\s\S]*?^\t\}/m)?.[0] ?? '';
if (!record) throw Error('Missing unit factory record');
const keys = new Set([...record.matchAll(/"(\w+)"\s*:/g)].map(match => match[1]));
const literal = '(?:true|false|null|-?\\d+(?:\\.\\d+)?|""|\\[\\]|\\{\\})';
const defaults = Object.fromEntries([...schema.matchAll(new RegExp('^\\s*"(\\w+)": \\{[^\\n]*?"default": ('+literal+')(?=,)', 'gm'))].map(match => [match[1],JSON.parse(match[2])]));
for (const match of record.matchAll(new RegExp('"(\\w+)":\\s*('+literal+')(?=[,\\s])','g'))) {
  if (declared.has(match[1]) && JSON.stringify(defaults[match[1]]) !== JSON.stringify(JSON.parse(match[2]))) throw Error('Unit default drift: '+match[1]);
}
const walk = dir => fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry => entry.isDirectory() ? walk(dir+'/'+entry.name) : entry.name.endsWith('.gd') ? [dir+'/'+entry.name] : []);
// Unit records are Dictionaries, so the receiver name is the only static hint that a
// write targets a unit. Cover the names used across the simulation, including the
// officer/worker aliases that used to slip past a four-name list.
const receivers = 'u|unit|nu|gate|commander|worker|member|leader|ship|target|other|attacker|victim';
for (const file of walk(root+'/simulation')) {
  const source = fs.readFileSync(file,'utf8');
  for (const match of source.matchAll(new RegExp('\\b(?:'+receivers+')\\.(\\w+)\\s*=(?!=)|\\b(?:'+receivers+')\\["(\\w+)"\\]\\s*=(?!=)','g'))) keys.add(match[1] ?? match[2]);
}
const missing = [...keys].filter(key => !declared.has(key));
if (missing.length) throw Error('Unregistered unit field writes: '+missing.join(', '));
console.log(`UNIT SCHEMA DECLARATIONS PASS ${declared.size} definitions / factory keys and literal unit writes covered`);
