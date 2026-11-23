import path from 'node:path';
import {sourceViews} from './gdscript_source.mjs';

const resource = String.raw`\b(?:preload|load)\s*\(\s*(['"])res:\/\/([^'"\r\n]+\.gd)\1\s*\)`;
const memberName = /^(?:[ \t]*(var)\s+|[ \t]*)(?:self\.)?(\w+)\s*(?::\s*\w+\s*)?:?=\s*$/;
const fnHeader = /^(?:static\s+)?func\s+(\w+)\([^\r\n]*\)\s*(?:->\s*[\w\[\]]+\s*)?:[ \t]*/gm;

function releaseCollections(functions) {
  const collections = new Map();
  for (const fn of functions.filter(({name}) => /^_owned_(services|components)$/.test(name))) {
    const fields = [...fn.body.matchAll(/:[ \t]*(?:self\.)?(\w+)[ \t]*(?=[,}\r\n])/g)].map(m => m[1]);
    for (const m of fn.body.matchAll(/\[\s*\]\s*=\s*(\w+)/g)) fields.push(m[1]);
    collections.set(fn.name, fields);
  }
  return collections;
}

function releaseSites(fn, collections) {
  const direct = [];
  const inLoops = new Set();
  for (const m of fn.body.matchAll(/(?<![\w.])(self\.)?(\w+)\.free\(\)/g)) direct.push({name: m[2], qualified: !!m[1], at: fn.start + m.index});
  for (const loop of fn.body.matchAll(/^([ \t]+)for\s+(\w+)\s+in\s+(\[[^\r\n]*\]|\w+\(\)\.values\(\))\s*:\s*\r?\n/gm)) {
    const [, indent, item, iterable] = loop;
    const start = loop.index + loop[0].length;
    const lines = fn.body.slice(start).match(/[^\n]*\n|[^\n]+$/g) ?? [];
    const end = lines.findIndex(line => line.trim() && (!line.startsWith(indent) || !/^[ \t]/.test(line[indent.length] ?? '')));
    const body = lines.slice(0, end < 0 ? lines.length : end).join('');
    if (!new RegExp('(?<![\\w.])' + item + '\\.free\\(\\)').test(body)) continue;
    const members = iterable.startsWith('[')
      ? iterable.slice(1, -1).split(',').map(name => name.trim().replace(/^self\./, ''))
      : collections.get(iterable.split('(')[0]) ?? [];
    for (const member of members) inLoops.add(member);
    // The loop variable belongs to the loop, not to a member of the same name.
    for (const site of direct) {
      if (!site.qualified && site.name === item && site.at >= fn.start + start && site.at < fn.start + start + body.length) site.loopVariable = true;
    }
  }
  return {direct: direct.filter(site => !site.loopVariable), inLoops};
}

export function objectOwnershipErrors(sources) {
  const views = new Map([...sources].map(([file, text]) => [file, sourceViews(text)]));
  const manual = new Set();
  let added;
  do {
    added = false;
    for (const [file, {code, uncommented}] of views) {
      if (manual.has(file)) continue;
      const declaration = [...uncommented.matchAll(/^extends\s+(['"])([^'"\r\n]+)\1/gm)]
        .find(match => code[match.index] === 'e');
      const parent = declaration?.[2];
      const base = parent?.startsWith('res://') ? parent.slice(6)
        : parent && path.posix.normalize(path.posix.join(path.posix.dirname(file), parent));
      if (/^extends Object\b/m.test(code) || manual.has(base)) {
        manual.add(file);
        added = true;
      }
    }
  } while (added);
  const errors = [];
  for (const [file, {code, uncommented}] of views) {
    const headers = [...code.matchAll(fnHeader)];
    const functions = headers.map((header, index) => {
      const start = header.index + header[0].length;
      const end = headers[index + 1]?.index ?? code.length;
      return {name: header[1], start, end, body: code.slice(start, end), signature: header[0]};
    });
    const fields = new Set([...code.matchAll(/^var\s+(\w+)/gm)].map(m => m[1]));
    const aliases = new Map([['Object', 'Object']]);
    const collections = releaseCollections(functions);
    const releases = functions.map(fn => releaseSites(fn, collections));
    const allocations = [];
    for (const m of uncommented.matchAll(new RegExp(resource, 'g'))) {
      if (!manual.has(m[2]) || !/\S/.test(code[m.index])) continue;
      const prefix = code.slice(code.lastIndexOf('\n', m.index) + 1, m.index);
      const alias = prefix.match(/^\s*(?:const|var)\s+(\w+)\s*(?::\s*Script\s*)?:?=\s*$/)?.[1];
      if (/^\s*\.new\s*\(/.test(code.slice(m.index + m[0].length))) {
        allocations.push({at: m.index, prefix, script: m[2]});
      } else if (alias) aliases.set(alias, m[2]);
    }
    for (const m of code.matchAll(/\b(\w+)\.new\s*\(/g)) {
      if (!aliases.has(m[1])) continue;
      allocations.push({at: m.index, prefix: code.slice(code.lastIndexOf('\n', m.index) + 1, m.index), script: aliases.get(m[1])});
    }
    for (const {at, prefix, script} of allocations) {
      const binding = prefix.match(memberName);
      const name = binding?.[2];
      const index = /^[ \t]/.test(prefix) ? functions.findIndex(fn => at >= fn.start && at < fn.end) : -1;
      const overwrites = new RegExp('(?:^|;)\\s*(?:var\\s+)?(?:self\\.)?' + name + '\\s*:?=(?!=)', 'm');
      const local = index >= 0 && binding?.[1];
      let owned = false;
      if (local) {
        const release = releases[index].direct.find(site => !site.qualified && site.name === name && site.at > at);
        // A second assignment could discard the first instance before free().
        owned = !!release && !overwrites.test(code.slice(at, release.at));
      } else if (name && fields.has(name)) {
        owned = releases.some((sites, i) => {
          if (i === index) return false;
          const shadow = new RegExp('\\bvar\\s+' + name + '\\b').test(functions[i].body)
            || new RegExp('[,(]\\s*' + name + '\\s*(?:[:,=)]|$)').test(functions[i].signature);
          return !shadow && sites.inLoops.has(name)
            || sites.direct.some(site => site.name === name && (site.qualified || !shadow));
        });
        if (owned && index >= 0) {
          const released = releases[index].direct.find(site => site.name === name && site.at > at);
          owned = !overwrites.test(code.slice(at, released?.at ?? functions[index].end));
        }
      }
      if (!owned) errors.push(file + ':' + code.slice(0, at).split('\n').length
        + ': Object instance ' + (name ?? '<unbound>') + ' (' + script + ') has no matching release');
    }
  }
  return errors;
}
