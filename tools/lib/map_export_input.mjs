import fs from 'node:fs';
import path from 'node:path';
import {header as medHeader, solveFile} from './medobjects.mjs';

export function loadMapObjects(options) {
  const medFile = path.join(options.meds, `${options.map}.MED`);
  const buf = fs.readFileSync(medFile);
  const h = medHeader(buf);
  const tail = new Map();
  if (fs.existsSync(options.tailmap)) {
    const tm = JSON.parse(fs.readFileSync(options.tailmap, 'utf8'));
    for (const k of ['tail0', 'tail2', 'tail4']) for (const u of tm[k] || []) tail.set(u, Number(k.slice(4)));
  }
  const r = solveFile(buf, h.dataStart + h.layerBytes + 40, tail, h);
  if (r.status !== 'ok') throw new Error(`solve failed for ${options.map}: ${r.status}`);
  const objects = r.objects.filter((x) => x.used);

  return {buf, h, objects};
}
