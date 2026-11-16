import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {runChecks} from './lib/ci_checks.mjs';

const groups = {
  architecture: ['architecture_check', 'test_architecture_check', 'port_inventory', 'battle_access_inventory', 'test_battle_access_inventory'],
  registry: ['registry_check', 'test_registry_check'],
  data: ['unit_schema_check', 'rules_manifest', 'data_check', 'test_scenario_generator', 'test_map_export_navigation', 'test_opening_forces'],
  docs: ['docs_lint', 'test_docs_lint', 'test_markdown_anchors'],
  repository: ['syntax_check', 'suite_check', 'test_suite_check', 'test_repository_policy', 'test_ci_checks'],
  tooling: ['test_engine_integrity', 'test_bootstrap', 'powershell_encoding', 'test_powershell_encoding',
    'test_godot_process', 'test_regression_result', 'test_terrain_dedup', 'test_terrain_equivalence', 'test_runtime_assets']
};
const args = process.argv.slice(2);
const group = args.includes('--group') ? args[args.indexOf('--group') + 1] : 'all';
if (group !== 'all' && !Object.hasOwn(groups, group)) throw Error('Unknown check group: ' + group);
const selected = group === 'all' ? Object.keys(groups) : [group];
const checks = selected.flatMap(name => groups[name].map(script => ({name: `${name}/${script}`,
  args: [`tools/${script}.mjs`, ...(script === 'docs_lint' ? ['--index'] : [])]})));
if (selected.includes('tooling')) checks.push({name: 'tooling/terrain-declarations', args: ['tools/compare_terrain_rebuild.mjs', '--declarations']});
const results = runChecks(checks, check => spawnSync(process.execPath, check.args, {stdio: 'inherit'}));
const directory = '_work/lightweight';
fs.mkdirSync(directory, {recursive: true});
fs.writeFileSync(path.join(directory, group + '.json'), JSON.stringify(results, null, 2) + '\n');
for (const result of results) console.log(`${result.ok ? 'PASS' : 'FAIL'} ${result.name}${result.error ? ': ' + result.error : ''}`);
const failed = results.filter(result => !result.ok);
console.log(`LIGHTWEIGHT CI ${failed.length ? 'FAIL' : 'PASS'} ${results.length - failed.length}/${results.length} checks (${group})`);
if (failed.length) process.exitCode = 1;
