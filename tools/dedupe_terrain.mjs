import {dedupeTerrain} from './lib/terrain_dedup.mjs';
if (!process.argv[2]) throw Error('Usage: node tools/dedupe_terrain.mjs <compiled-stage>');
console.log('TERRAIN DEDUP', JSON.stringify(dedupeTerrain(process.argv[2])));
