import fs from 'node:fs';
import path from 'node:path';

export function writeMapExport(options, data, {baked, objects, unitMeta, sheetKeys}) {
  fs.mkdirSync(path.join(options.outDir, 'data'), { recursive: true });
  fs.writeFileSync(path.join(options.outDir, 'data', `${options.map.toLowerCase()}.json`), JSON.stringify(data));

  // ---------- report ----------
  console.log(`${options.map} "${data.name}"  terrain ${baked.W}x${baked.H}`);
  console.log(`  objects: ${objects.length}  owners: ${[...new Set(objects.map((x) => x.owner))].sort().join(',')}`);
  const byUnit = new Map();
  for (const x of objects) byUnit.set(x.unit, (byUnit.get(x.unit) || 0) + 1);
  for (const u of [...byUnit.keys()].sort((a, b) => a - b)) {
    const meta = unitMeta[String(u)];
    console.log(`    unit ${String(u).padStart(2)} ${(meta?.name || '??').padEnd(8)} ${meta ? meta.w + 'x' + meta.h : ''}  x${byUnit.get(u)}`);
  }
  console.log(`  sprites: ${sheetKeys.size} sheets (unit x owner, all animation frames)`);
  console.log(`  wrote: data/${options.map.toLowerCase()}.json (${options.legacyArt ? 'research images' : 'HD catalog references; no native image output'})`);

}
