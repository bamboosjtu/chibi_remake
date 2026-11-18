import fs from 'node:fs';
import path from 'node:path';
import {validateInternalScope} from './lib/internal_contracts.mjs';
const root = 'godot/chibi_remake';
const walk = dir => fs.readdirSync(dir, {withFileTypes:true}).flatMap(entry => entry.name.startsWith('.') || ['art','media','data','assets','addons'].includes(entry.name) ? [] : entry.isDirectory() ? walk(dir+'/'+entry.name) : entry.name.endsWith('.gd') ? [dir+'/'+entry.name] : []);
const sources = Object.fromEntries(walk(root).map(file => [path.relative(root,file).replaceAll('\\','/'),fs.readFileSync(file,'utf8')]));
const registry = JSON.parse(fs.readFileSync('tools/inputs/composition.json','utf8'));
const layer = file => file.split('/')[0];
const ports = Object.entries(registry.ports).map(([file, entry]) => {
  const code = sources[file];
  const contract = JSON.parse(code.match(/^const CONTRACTS := (.+)$/m)[1]);
  const consumers = Object.entries(sources).filter(([name, text]) => name !== file && text.includes('res://'+file)).map(([name]) => name);
  const domain = file.match(/\/([^/]+)_access\.gd$/)?.[1];
  if (domain) for (const [name,text] of Object.entries(sources)) if (text.includes(`simulation_access("${domain}")`) && !consumers.includes(name)) consumers.push(name);
  const providers = Object.fromEntries(Object.entries(contract).map(([name, methods]) => [name, {file:registry.hosts[entry.host][name], methods}]));
  const methods = [...code.matchAll(/^func (\w+)\([^]*?(?=^func |^const |^var |$(?![^]))/gm)].map(match => {
    const name = match[1], body = match[0];
    const provider = body.match(/_require\(_provider_(\w+)/)?.[1];
    const forwarded = body.match(/provider\.(\w+)\(/)?.[1];
    const crossLayer = provider && layer(file) !== layer(providers[provider].file);
    const lifecycle = ['_init','connect_services','disconnect_services'].includes(name);
    const mechanical = !!forwarded && body.trimEnd().split('\n').length <= 5;
    const category = lifecycle ? 'module-capability' : crossLayer ? 'cross-layer' : forwarded?.startsWith('_') ? 'private-contract' : mechanical ? 'pure-forwarding' : 'module-capability';
    const nameMatches = consumers.filter(consumer => new RegExp('\\.'+name+'\\s*\\(').test(sources[consumer]));
    return {name, category, ...(provider ? {provider, forwarded, mechanical, privateContract:forwarded?.startsWith('_') ?? false} : {}), nameMatches};
  });
  return {file, host:entry.host, kind:'guarded-adapter', consumers:consumers.sort(), providers, methods};
});
const internalScopes=Object.entries(registry.internalScopes).map(([file,entry])=>{
 const declared=JSON.parse(sources[file].match(/^const REQUIRED_SERVICES := (.+)$/m)[1]);
 return {file,host:entry.host,category:'module-capability',providers:declared,resolvedCalls:validateInternalScope(file,sources[file],declared)};
});
const mechanicalForwarders = ports.flatMap(port => port.methods).filter(method => method.mechanical).length;
const limits = JSON.parse(fs.readFileSync('tools/inputs/architecture_limits.json', 'utf8'));
if (mechanicalForwarders > limits.mechanicalForwarders) {
  throw Error('Mechanical forwarders increased to ' + mechanicalForwarders + ' (limit ' + limits.mechanicalForwarders + ')');
}
const report = {schemaVersion:3, mechanicalForwarders, safeForAutomatedDeletion:false, receiverResolution:"partial", method:'Internal scopes verify a restricted literal acquire/guard/direct-receiver form against the composition manifest. Other adapters retain method-name hints only: positive matches may refer to another object, and zero matches do not prove dead code because signals/Callables and inherited adapters exist. This is not a general syntax-tree call graph or deletion evidence.', ports,internalScopes};
const target = 'tools/inputs/port_inventory.json', text = JSON.stringify(report,null,2)+'\n';
if (process.argv.includes('--write')) fs.writeFileSync(target,text);
else if (!fs.existsSync(target) || fs.readFileSync(target,'utf8') !== text) throw Error('Port inventory stale; review and run node tools/port_inventory.mjs --write');
console.log(`PORT INVENTORY PASS ${ports.length} guarded adapters / ${internalScopes.length} internal scopes / name-match hints and verified internal receivers`);
