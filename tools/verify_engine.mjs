import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const engine=path.resolve(option('--engine','Godot_v4.7.2-stable_win64.exe'));
const platform=option('--platform',process.platform);
const lock=JSON.parse(fs.readFileSync(new URL('./inputs/engines.json',import.meta.url),'utf8'));
const expected=lock.sha256[platform];if(!expected)throw Error('No reviewed engine hash for '+platform);
const actual=crypto.createHash('sha256').update(fs.readFileSync(engine)).digest('hex');
if(actual!==expected)throw Error('Engine differs from the reviewed '+lock.version+' bytes; expected '+expected+', actual '+actual);
console.log('ENGINE INTEGRITY PASS '+platform+' / '+lock.version+' / '+actual);
