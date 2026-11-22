import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {ignoreAllowlist} from './lib/runtime_assets.mjs';
const parent = path.resolve('_work/runtime-assets-fixtures');
fs.mkdirSync(parent, {recursive:true});
const fixture = fs.mkdtempSync(path.join(parent,'case-'));
const script = path.resolve('tools/runtime_assets.mjs');
try {
  const asset = 'art/full/ui/probe.png', bytes = Buffer.from('asset-A');
  const filename = path.join(fixture,'godot/chibi_remake',asset);
  fs.mkdirSync(path.dirname(filename), {recursive:true}); fs.writeFileSync(filename,bytes);
  fs.mkdirSync(path.join(fixture,'tools/inputs'), {recursive:true});
  fs.writeFileSync(path.join(fixture,'tools/inputs/runtime_assets.sha256'), `${crypto.createHash('sha256').update(bytes).digest('hex')}\t${bytes.length}\t${asset}\n`);
  fs.writeFileSync(path.join(fixture,'.gitignore'),ignoreAllowlist([{path:asset,metadata:[]}])+'\n');
  const run = () => spawnSync(process.execPath,[script,'--check','--hash','--versioned-only'],{cwd:fixture,encoding:'utf8'});
  assert.equal(run().status,0,'Versioned verification must not require generated terrain');
  fs.writeFileSync(filename,Buffer.from('asset-B'));
  assert.notEqual(run().status,0,'Same-size tampering must fail');
  fs.unlinkSync(filename); assert.notEqual(run().status,0,'Missing versioned asset must fail');
  console.log('VERSIONED ASSETS NEGATIVE PASS no generated cache needed / same-size tamper / missing bytes rejected');
} finally {
  assert.equal(path.dirname(fixture),parent); fs.rmSync(fixture,{recursive:true,force:true});
}
