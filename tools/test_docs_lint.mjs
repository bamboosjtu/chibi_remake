import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const parent = path.join(source, '_work/architecture-tests');
fs.mkdirSync(parent, {recursive: true});
const fixture = fs.mkdtempSync(path.join(parent, 'docs-links-'));
const write = (name, text) => {
  const target = path.join(fixture, name);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.writeFileSync(target, text);
};
const git = (...args) => {
  const result = spawnSync('git', args, {cwd: fixture, encoding: 'utf8', windowsHide: true});
  assert.equal(result.status, 0, result.stderr);
};
const lint = (indexed = true) => {
  const result = spawnSync(process.execPath, ['tools/docs_lint.mjs', ...(indexed ? ['--index'] : [])],
    {cwd: fixture, encoding: 'utf8', windowsHide: true});
  assert.ifError(result.error);
  return {code: result.status, output: result.stdout + result.stderr};
};
const expect = (code, message) => {
  const result = lint();
  assert.equal(result.code, code, result.output);
  if (message) assert(result.output.includes(message), result.output);
};

for (const file of ['tools/docs_lint.mjs', 'tools/lib/markdown_anchors.mjs'])
  write(file, fs.readFileSync(path.join(source, file), 'utf8'));
const copyDocs = (dir, rel) => {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) copyDocs(full, rel + '/' + entry.name);
    else if (entry.name.endsWith('.md')) write(rel + '/' + entry.name, '# Fixture\n');
  }
};
copyDocs(path.join(source, 'docs'), 'docs');
write('docs/reference/level-openings.md', Array.from({length: 34}, (_, i) => '### Level ' + i).join('\n') +
  '\n' + '- 敌方：fixture\n'.repeat(73));
write('docs/链接目标.md', '# 功能\n');
write('.gitignore', 'ignored/\n');
write('README.md', '[tracked](docs/80-runtime/01-architecture.md)\n[directory](docs/)\n[unicode](docs/%E9%93%BE%E6%8E%A5%E7%9B%AE%E6%A0%87.md#功能)\n');
git('init', '--quiet');
git('add', '.');
expect(0);

write('ignored/report.md', '# Local report\n');
write('README.md', '[local](ignored/report.md)\n');
assert.equal(lint(false).code, 0, 'Control: the existing local file satisfies filesystem-only lint');
expect(1, 'not versioned; absent from clean checkout');

write('local-only/report.md', '# Draft\n');
write('README.md', '[local directory](local-only/)\n');
expect(1, 'not versioned; absent from clean checkout');
git('add', 'local-only/report.md');
expect(0);

write('README.md', '[missing](docs/missing.md)\n');
expect(1, 'docs/missing.md');
write('README.md', '[wrong heading](docs/链接目标.md#不存在)\n');
expect(1, 'missing heading');

console.log('DOC LINKS PASS tracked files/directories / Unicode anchors / ignored and untracked targets rejected / missing files and headings rejected');
