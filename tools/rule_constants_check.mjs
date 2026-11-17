import fs from 'node:fs';
import path from 'node:path';
import {valueHash,sourceViolations,documentation} from './lib/rule_constants.mjs';
const args=process.argv.slice(2),option=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const root=option('--root','godot/chibi_remake'),docFile=option('--docs','docs/05-production-tech.md');
const read=name=>JSON.parse(fs.readFileSync(path.join(root,'data/db',name+'.json'),'utf8'));
const values={tech:read('tech'),unit_roles:read('unit_roles'),balance:read('balance')};
const baseline=JSON.parse(fs.readFileSync('tools/inputs/rule_constants_baseline.json','utf8'));
const failures=[];
for(const [name,data]of Object.entries(values))if(valueHash(data)!==baseline.sha256[name])failures.push(name+': reviewed behavior baseline changed');
const walk=directory=>fs.readdirSync(directory,{withFileTypes:true}).flatMap(e=>e.name.startsWith('.')||['art','media','assets','addons','data'].includes(e.name)?[]:e.isDirectory()?walk(path.join(directory,e.name)):e.name.endsWith('.gd')?[path.join(directory,e.name)]:[]);
for(const file of walk(root))for(const error of sourceViolations(fs.readFileSync(file,'utf8'),values.unit_roles))failures.push(path.relative(root,file)+': '+error);
const native=fs.readFileSync(option('--native-source','tools/native/sim_math/sim_math.cpp'),'utf8');
if(/integer\(u,\s*k\.unit[^)]*\)\s*==\s*47\b/.test(native))failures.push('native: duplicated transport classification');
let doc=fs.readFileSync(docFile,'utf8').replaceAll('\r\n','\n');
for(const [name,text]of Object.entries(documentation(values.tech,values.unit_roles,values.balance))){
 const block=`<!-- RULE-${name}:BEGIN -->\n${text}\n<!-- RULE-${name}:END -->`;
 const re=new RegExp(`<!-- RULE-${name}:BEGIN -->[\\s\\S]*?<!-- RULE-${name}:END -->`);
 if(!re.test(doc))failures.push('Missing generated documentation block: '+name);
 else if(args.includes('--write'))doc=doc.replace(re,block);
 else if(doc.match(re)[0]!==block)failures.push('Rule documentation stale: '+name+'; run node tools/rule_constants_check.mjs --write');
}
if(args.includes('--write'))fs.writeFileSync(docFile,doc);
if(failures.length){for(const failure of failures)console.error(failure);process.exitCode=1;}
else console.log('RULE CONSTANTS PASS reviewed values / unique role and cap sources / generated technology documentation / native transport injection');
