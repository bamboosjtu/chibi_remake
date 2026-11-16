import fs from 'node:fs';
import {suites, checkInventory} from './lib/suite_inventory.mjs';
const inputs = Object.fromEntries([...suites, 'manual_tests'].map(name => [name, JSON.parse(fs.readFileSync(`tools/inputs/${name}.json`, 'utf8'))]));
const errors = checkInventory('tools/gd', inputs);
for (const file of ['LICENSE', 'NOTICE.md', 'docs/20-legal.md']) if (!fs.statSync(file).size) errors.push('Empty notice: ' + file);
if (errors.length) {console.error(errors.join('\n')); process.exitCode = 1;}
else console.log('SUITE INVENTORY PASS every tools/gd script classified; automatic suites require pass markers');
