import fs from 'node:fs';

// Level metadata retains native world dimensions and animation indices. Image
// paths identify the HD catalog; they are never interpreted as native sheets.
export function useRuntimeArt(level, project = 'godot/chibi_remake') {
  const manifest = JSON.parse(fs.readFileSync(`${project}/art/full/manifest.json`));
  const ref = id => {
    const atlas = manifest.atlases[String(id)];
    if (!atlas) throw new Error(`Missing HD atlas for unit ${id}`);
    return atlas.texture.replace(/^res:\/\//, '');
  };
  for (const ob of level.objects) ob.sheet = ref(ob.unit);
  for (const [id, meta] of Object.entries(level.units)) {
    meta.sheet = ref(id);
    meta.sheetK = 1;
  }
  level.terrain = `art/full/terrain_chunks/${level.map.toLowerCase()}/manifest.json`;
  delete level.terrainHD;
  delete level.terrainScale;
  delete level.spriteK;
  level.artMode = 'hd-catalog';
  return level;
}
