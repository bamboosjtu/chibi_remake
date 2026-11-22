// All buildable definitions must exist even when the MED contains none of them.
export function completeBuildings(units, registry, data, manifest) {
  for (const building of data.buildings) {
    const id = building.id, rec = registry.units.find(u => u.id === id), v = building.v;
    if (!rec || !manifest.atlases[String(id)]) throw new Error(`Missing building definition/art: ${id}`);
    units[String(id)] = {
      ...units[String(id)], name: building.name, spriteName: rec.spriteName,
      w: rec.width, h: rec.height, frames: { first: rec.firstFrame, count: rec.frameCount, cols: 8 },
      clips: {}, building: true, hp: v[0], attack: 0, attackB: v[1], defence: v[2], defenceB: v[3],
      mitig: v[2], mitig2: v[3], vision: v[4], range: v[5], f9: v[6],
      costStone: v[7], costs: [v[8], v[9], 0], expGain: v[11], moraleGain: v[12],
      sheetK: 1, sheet: manifest.atlases[String(id)].texture.replace(/^res:\/\//, '')
    };
  }
}
