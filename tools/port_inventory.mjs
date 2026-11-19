import fs from 'node:fs';
import path from 'node:path';
const root = 'godot/chibi_remake';
const retiredPaths = /^(?:simulation\/ports\/|app\/commands\/|app\/battle_commands\.gd$|simulation\/service_dependencies\.gd$)/;
const retired = /\b(?:REQUIRED_SERVICES|_provider_\w+|simulation_access)\b|\bports\.acquire\(/;
function visit(directory) {
 for (const entry of fs.readdirSync(directory, {withFileTypes:true})) {
  if (entry.name.startsWith('.') || ['addons','assets','art','media','data'].includes(entry.name)) continue;
  const file = path.join(directory,entry.name);
  if (entry.isDirectory()) visit(file);
  else if (entry.name.endsWith('.gd') && (retiredPaths.test(path.relative(root,file).split(path.sep).join('/')) || retired.test(fs.readFileSync(file,'utf8')) || /(?:_dependencies|named_port)\.gd$/.test(file))) {
   throw new Error('Retired dependency adapter in ' + file);
  }
 }
}
visit(root);
console.log('PORT INVENTORY PASS zero legacy providers, scoped acquisitions or dependency adapters');
