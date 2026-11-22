#!/usr/bin/env node
// 审看图片后显式登记结果；此脚本不执行自动美术判定。
import fs from 'node:fs';
const [state,reason,...ids]=process.argv.slice(2);
if(!['pass','fail'].includes(state)||!reason||!ids.length)throw new Error('usage: node remaster_review.mjs pass|fail "review reason" asset-id ...');
for(const id of ids) {
  const file=`godot/chibi_remake/art/production/deliveries/${id}.json`;
  const record=JSON.parse(fs.readFileSync(file));
  if(state==='pass'&&record.validation?.structure!=='pass')throw new Error(`${id}: structure validation required`);
  record.validation={...(record.validation||{}),visual:state};
  record.visualReview={state,reason,reviewer:'Codex source/reference comparison',reviewedSha256:record.sha256,reviewedAt:new Date().toISOString()};
  fs.writeFileSync(file,JSON.stringify(record,null,2));
}
console.log(`Visual review ${state}: ${ids.length} assets.`);
