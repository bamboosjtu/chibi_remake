import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const parent=path.resolve('_work/engine-integrity-tests');fs.mkdirSync(parent,{recursive:true});const file=path.join(parent,'unreviewed-engine.bin');fs.writeFileSync(file,'unreviewed bits');
const r=spawnSync(process.execPath,['tools/verify_engine.mjs','--engine',file],{encoding:'utf8'});assert.notEqual(r.status,0);assert.match(r.stderr,/Engine differs from the reviewed/);
console.log('ENGINE INTEGRITY NEGATIVE PASS unreviewed binary rejected before execution');
