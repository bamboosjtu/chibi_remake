import assert from 'node:assert/strict';
import {buildNavigation} from './lib/map_export_navigation.mjs';

// A gate may reopen traversable ground under a structure; cliffs remain blocked.
const mm = {rows: 3, cols: 3, layers: [
  [[0xf000, 0xf000, 0xffff], [0x8000, 0x9000, 0x2000], [0xf000, 0xf000, 0xf000]],
  [[0xffff, 1, 0xffff], [0xffff, 0xffff, 0xffff], [0xffff, 0xffff, 0xffff]],
  Array.from({length: 3}, () => Array(3).fill(0xffff)),
]};
const terrain = buildNavigation(mm, []);
assert.deepEqual(terrain.terrainWalk, [1, 0, 0, 1, 1, 0, 1, 1, 1]);
const gate = buildNavigation(mm, [{unit: 16, A: 1, B: 1}]);
assert.equal(gate.terrainWalk[1], 1);
assert.equal(gate.terrainWalk[2], 0);
assert.equal(gate.terrainWalk[5], 0);
assert.equal(gate.walk[4], 0);
assert.equal(gate.gateOpen, 1);
assert.ok(gate.decor.some(([a, b, phase]) => a === 1 && b === 0 && phase === 1));
console.log('MAP EXPORT NAVIGATION PASS terrain / structures / gate passages / building placement / decor');
