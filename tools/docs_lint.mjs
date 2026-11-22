#!/usr/bin/env node
/**
 * docs_lint.mjs —— 开发规格文档自检
 *
 * 检查 1（规格纯净度，报错，退出码 1）：
 *   docs/*.md 与 docs/reference/*.md 只描述现行规格，不出现逆向表述、原版依据、
 *   日期化过程记录与完成度口吻。
 *
 * 检查 2（本地链接，报错，退出码 1）：
 *   扫描仓库根 Markdown、docs/**、godot/chibi_remake/README.md 的相对链接；
 *   目标不存在即报错（http/https/#锚点跳过）。
 *
 * 检查 3（附录完整度，报错，退出码 1）：
 *   docs/reference/level-openings.md 必须包含 34 个关卡小节与 73 条参战方记录。
 *
 * 用法：
 *   node tools/docs_lint.mjs        # 输出明细；任一检查有命中则退出码 1
 *   node tools/docs_lint.mjs -q     # 只输出计数
 *   node tools/docs_lint.mjs --index # 链接目标还必须在 Git 索引中，不能依赖本机报告
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {execFileSync} from 'node:child_process';
import {headingAnchors} from './lib/markdown_anchors.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = path.join(ROOT, 'docs');

// 逆向/依据/过程口吻。只用于规格区；代码注释与内部工具不受此检查约束。
const FORBIDDEN = [
  /逆向|反编译|反汇编|破解|取证/,
  /CONF-\d/,
  /CB\.EXE|BATTLE\.EXP|DATA\.EXP|ANISEQ|INTERFAC\.EXP|WAVE\.EXP/,
  /\.LWC|\.MED\b|\bMED\b/,
  /原版/,
  /REMAKE-GAP|研究区|研究索引|待裁决|已结案/,
  /待确认|待验证|已实现|已接入|回归通过|专项回归|源码回归/,
  /本轮|上一轮|评审基线|修复记录|变更记录/,
  /\b20\d{2}[-/年]\d{1,2}([-/月]\d{1,2})?/,
];

const REQUIRED = [
  '00-meta/01-overview.md', '10-world/01-game-flow.md', '10-world/02-battlefield.md',
  '10-world/03-campaign.md', '20-units/01-units-officers.md', '30-combat/01-combat.md',
  '30-combat/02-abilities.md', '40-economy/01-economy.md', '40-economy/02-buildings.md',
  '40-economy/03-production-tech.md', '50-command-ui/01-interface.md', '60-ai/01-ai.md',
  '70-presentation/01-audio-media.md', '70-presentation/02-art.md', '80-runtime/01-architecture.md',
  '80-runtime/02-data-spec.md', '80-runtime/03-save-compat.md', '80-runtime/04-build-release.md',
  '80-runtime/05-testing.md', '95-legal/01-legal.md',
];

const quiet = process.argv.includes('-q');
// CI checks a clean checkout. Existing local reports must not mask missing
// repository inputs when running the same gate before a push.
const indexed = process.argv.includes('--index');
const versioned = new Set();
if (indexed) {
  const files = execFileSync('git', ['ls-files', '--cached', '-z'], {cwd: ROOT, encoding: 'utf8'}).split('\0').filter(Boolean);
  for (const file of files) {
    versioned.add(file);
    let parent = path.posix.dirname(file);
    while (parent !== '.') { versioned.add(parent); parent = path.posix.dirname(parent); }
  }
  if (files.length) versioned.add('');
}
const purity = [];
const brokenLinks = [];
const appendix = [];
const missing = [];

function walkMd(dir, out) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === '_work' || entry.name === 'release' || entry.name === 'node_modules') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walkMd(full, out);
    else if (entry.name.endsWith('.md')) out.push(full);
  }
}

// ---- 检查 1：规格纯净度 ----
// 模块化布局后，规格文件分布在 docs/<module>/*.md；附录保持在 docs/reference/。
const specFiles = [];
walkMd(DOCS, specFiles);
for (const file of specFiles) {
  const rel = path.relative(ROOT, file).replaceAll('\\', '/');
  fs.readFileSync(file, 'utf8').split(/\r?\n/).forEach((line, i) => {
    for (const rule of FORBIDDEN) {
      if (rule.test(line)) {
        purity.push(`${rel}:${i + 1}: ${line.trim().slice(0, 140)}`);
        break;
      }
    }
  });
}

// ---- 检查 2：本地链接 ----
const mdFiles = [];
for (const rel of ['README.md', 'NOTICE.md']) {
  const full = path.join(ROOT, rel);
  if (fs.existsSync(full)) mdFiles.push(full);
}
walkMd(DOCS, mdFiles);
walkMd(path.join(ROOT, 'godot/chibi_remake'), mdFiles);
for (const file of mdFiles) {
  const text = fs.readFileSync(file, 'utf8');
  const re = /\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
  let m;
  while ((m = re.exec(text))) {
    let target = m[1];
    if (/^[a-z]+:/i.test(target)) continue;
    const [filePart,fragment]=target.split('#');
    target=filePart;
    let decoded = target;
    try { decoded = decodeURIComponent(target); } catch { /* keep raw */ }
    const resolved = target ? path.resolve(path.dirname(file), decoded) : file;
    if (!fs.existsSync(resolved)) {
      brokenLinks.push(path.relative(ROOT, file).replaceAll('\\', '/') + ' -> ' + target);
    } else if (indexed && !versioned.has(path.relative(ROOT, resolved).replaceAll('\\', '/'))) {
      brokenLinks.push(path.relative(ROOT, file).replaceAll('\\', '/') + ' -> ' + target + ' (not versioned; absent from clean checkout)');
    } else if(fragment && resolved.endsWith('.md')) {
      let anchor=fragment;try{anchor=decodeURIComponent(fragment);}catch{}
      if(!headingAnchors(fs.readFileSync(resolved,'utf8')).has(anchor))brokenLinks.push(path.relative(ROOT,file).replaceAll('\\','/')+' -> '+filePart+'#'+fragment+' (missing heading)');
    }
  }
}

for(const file of specFiles){
 const chapters=new Set();for(const match of fs.readFileSync(file,'utf8').matchAll(/^## (\d+)\. /gm)){
  if(chapters.has(match[1]))brokenLinks.push(path.relative(ROOT,file)+': duplicate chapter '+match[1]);chapters.add(match[1]);
 }
}

// ---- 检查 3：附录完整度 ----
const appendixPath = path.join(DOCS, 'reference', 'level-openings.md');
if (!fs.existsSync(appendixPath)) {
  appendix.push('docs/reference/level-openings.md: 缺失（运行 node tools/lib/openings.mjs 生成）');
} else {
  const text = fs.readFileSync(appendixPath, 'utf8');
  const sections = (text.match(/^### /gm) ?? []).length;
  const sides = (text.match(/^- (?:★玩家|敌方)：/gm) ?? []).length;
  if (sections !== 34) appendix.push(`docs/reference/level-openings.md: 关卡小节 ${sections} 个（应为 34）`);
  if (sides !== 73) appendix.push(`docs/reference/level-openings.md: 参战方记录 ${sides} 条（应为 73）`);
}

// ---- 章节齐全 ----
for (const name of REQUIRED) {
  if (!fs.existsSync(path.join(DOCS, name))) missing.push(`docs/${name}`);
}

const errors = purity.length + brokenLinks.length + appendix.length + missing.length;
if (quiet) {
  console.log(`spec purity: ${purity.length} issue(s); broken links: ${brokenLinks.length}; appendix: ${appendix.length}; missing chapters: ${missing.length}`);
} else {
  if (missing.length) {
    console.log('== 缺少章节 ==');
    missing.forEach((x) => console.log('ERR ' + x));
  }
  if (purity.length) {
    console.log('== 规格纯净度（需修正）==');
    purity.forEach((x) => console.log('ERR ' + x));
  }
  if (appendix.length) {
    console.log('== 附录完整度 ==');
    appendix.forEach((x) => console.log('ERR ' + x));
  }
  if (brokenLinks.length) {
    console.log(`== 本地链接缺失（需修正 ${brokenLinks.length} 条）==`);
    brokenLinks.slice(0, 40).forEach((x) => console.log('ERR ' + x));
  }
  console.log(`\nspec purity: ${purity.length} issue(s); broken links: ${brokenLinks.length}; appendix: ${appendix.length}; missing chapters: ${missing.length}`);
}
process.exit(errors ? 1 : 0);
