import fs from 'node:fs';
export const suites = ['ci_godot_tests', 'save_tests', 'release_tests', 'development_tests', 'known_failures'];
export function checkInventory(directory, inputs) {
  const errors = [], covered = new Set(), exclusive = new Set();
  const files = new Set(fs.readdirSync(directory).filter(file => file.endsWith('.gd')).map(file => file.slice(0, -3)));
  for (const name of suites) {
    const seen = new Set();
    for (const test of inputs[name].tests) {
      if (!files.has(test.script)) errors.push(`${name}: missing script ${test.script}`);
      if (seen.has(test.script) || (!['ci_godot_tests', 'save_tests'].includes(name) && exclusive.has(test.script))) errors.push(`${name}: duplicate ${test.script}`);
      if (!Array.isArray(test.markers) || !test.markers.length || test.markers.some(marker => typeof marker !== 'string' || !marker.trim())) errors.push(`${test.script}: missing pass markers`);
      if (name === 'known_failures' && !test.expectedFailure) errors.push(`${test.script}: missing expectedFailure`);
      if (test.fixture && test.fixture !== 'opening-forces') errors.push(`${test.script}: unknown fixture ${test.fixture}`);
      seen.add(test.script); covered.add(test.script);
      if (!['ci_godot_tests', 'save_tests'].includes(name)) exclusive.add(test.script);
    }
  }
  for (const test of inputs.manual_tests.tests) {
    if (!files.has(test.script)) errors.push(`manual_tests: missing script ${test.script}`);
    if (covered.has(test.script)) errors.push(`manual_tests: duplicate ${test.script}`);
    if (!['manual', 'packaged', 'fixture', 'tool', 'wrapper'].includes(test.category) || !test.reason?.trim() || !test.command?.trim()) errors.push(`${test.script}: missing classification/reason/command`);
    covered.add(test.script);
  }
  for (const file of files) if (!covered.has(file)) errors.push(`Unclassified Godot script: ${file}`);
  return errors;
}
