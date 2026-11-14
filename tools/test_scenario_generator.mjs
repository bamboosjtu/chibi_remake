import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {definitions,generate,commitOutputs} from './lib/scenario_rules.mjs';
const root=path.resolve('_work/review-gameplay-20261114/generator');fs.mkdirSync(root,{recursive:true});
const data=definitions();assert(data.missions['29'].stages.some(s=>s.win&&s.condition.kind==='side_cleared'&&s.condition.sideIndex===2));
assert(data.missions['14'].stages.every(s=>s.condition.side==='enemy'));
assert(data.missions['14'].stages.find(s=>s.id==='rect').lose);
generate(['--rules-only','--check']);generate(['--rules-only','--output',root]);
const file=path.join(root,'scenario_rules.json'),before=fs.readFileSync(file);
assert.throws(()=>generate(['--output',root,'--events',path.join(root,'missing.EXT')]));assert.deepEqual(fs.readFileSync(file),before);
const other=path.join(root,'events.json');fs.writeFileSync(other,'old events');
const rename=fs.renameSync;let injected=false;try{fs.renameSync=(from,to)=>{if(to===other&&!injected){injected=true;throw Error('replace failure');}return rename(from,to);};
 assert.throws(()=>commitOutputs([[file,{new:1}],[other,{new:2}]]));
}finally{fs.renameSync=rename;}
assert.deepEqual(fs.readFileSync(file),before);assert.equal(fs.readFileSync(other,'utf8'),'old events');
assert(fs.readdirSync(root).every(f=>!f.includes('.tmp-')));
console.log('SCENARIO GENERATOR PASS regenerated equivalence / mission29 and L14 / missing-input atomicity / replace rollback');
