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
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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
  '01-overview.md', '02-game-flow.md', '03-economy.md', '04-buildings.md',
  '05-production-tech.md', '06-combat.md', '07-units-officers.md', '08-abilities.md',
  '09-ai.md', '10-battlefield.md', '11-campaign.md', '12-interface.md',
  '13-audio-media.md', '14-architecture.md', '15-data-spec.md', '16-save-compat.md',
  '17-art.md', '18-build-release.md', '19-testing.md', '20-legal.md',
];

const quiet = process.argv.includes('-q');
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
const specFiles = [];
for (const name of fs.readdirSync(DOCS)) {
  if (name.endsWith('.md')) specFiles.push(path.join(DOCS, name));
}
for (const name of fs.readdirSync(path.join(DOCS, 'reference'))) {
  if (name.endsWith('.md')) specFiles.push(path.join(DOCS, 'reference', name));
}
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
    if (/^[a-z]+:/i.test(target) || target.startsWith('#')) continue;
    target = target.split('#')[0];
    if (!target) continue;
    let decoded = target;
    try { decoded = decodeURIComponent(target); } catch { /* keep raw */ }
    const resolved = path.resolve(path.dirname(file), decoded);
    if (!fs.existsSync(resolved)) {
      brokenLinks.push(path.relative(ROOT, file).replaceAll('\\', '/') + ' -> ' + target);
    }
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
