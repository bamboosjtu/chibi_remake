import fs from 'node:fs';
import assert from 'node:assert/strict';
import {writeCatalog,assertUnpublishedTarget} from './lib/catalog_io.mjs';
const dir='_work/architecture-tests/catalog';fs.mkdirSync(dir,{recursive:true});
const file=dir+'/catalog.json';
fs.writeFileSync(file,JSON.stringify({assets:[{assetId:'approved',target:'keep-v1.png',status:'user-accepted',columns:4}],pages:[],visualReviewPolicy:{reviewer:'user'},additionalBanks:{}}));
writeCatalog(file,{assets:[{assetId:'approved',target:'replace-v2.png',columns:8}],pages:[]});
const before=JSON.parse(fs.readFileSync(file));
assert.equal(before.assets[0].target,'keep-v1.png');assert.equal(before.assets[0].columns,4);
const changed=structuredClone(before);changed.assets.push({assetId:'new',target:'pending.png'});writeCatalog(file,changed);
assert.throws(()=>writeCatalog(file,before),/changed while/);
const target=dir+'/immutable.bin';fs.writeFileSync(target,Buffer.from('original'));
assertUnpublishedTarget({target},Buffer.from('original'));
assert.throws(()=>assertUnpublishedTarget({target},Buffer.from('replacement')),/Immutable/);
const coverage=JSON.parse(fs.readFileSync('godot/chibi_remake/art/production/coverage.json'));
assert.equal(coverage.sourceFrameFallbacks.length,3028);
const manifest=JSON.parse(fs.readFileSync('godot/chibi_remake/art/full/manifest.json'));
assert.equal(Object.keys(manifest.atlases).length,53);
for(const atlas of Object.values(manifest.atlases)) {
  assert(fs.existsSync('godot/chibi_remake/'+atlas.texture.replace('res://','')));
  assert(atlas.frames.every(frame=>!frame.original));
}
const shader=fs.readFileSync('godot/chibi_remake/art/full/team_color.gdshader','utf8');
assert(shader.includes('texture(team_mask, UV)'));assert(!shader.includes('cyan_blue'));
assert(shader.includes('mask_value.r * mask_value.a'));
console.log('ARCH-024/025 PASS: 53 HD atlases, immutable targets, protected approvals, stale-write rejection, 3028 archival records');
