#!/usr/bin/env node
// REQ-004（review.md R-04）：构建输入引导——一个入口完成「审计 → 落位 → 构建」。
//
//   node tools/bootstrap.mjs --check      审计 tools/inputs/manifest.json 的全部输入，
//                                        缺项逐条给出落位指引，**缺项即非零退出**；
//   node tools/bootstrap.mjs --hashes     为 dec（可哈希的中间表）生成 sha256 快照
//                                        到清单的 hashFile，供新工作区校验外部工件副本；
//   node tools/bootstrap.mjs --check [-SkipData] ... 修改构建参数前仍需全绿；
//   node tools/bootstrap.mjs --build [构建参数...]  审计通过后按清单 build.entry 执行
//                                        （默认转发 powershell tools/build_release.ps1）。
//
// 设计立场：本脚本**只审计与引导，不猜**——没有任何一项输入会被静默当作存在，
// 也不会替用户决定"少一个输入也能凑合跑"。缺什么就说什么，然后按需退出。

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = process.cwd();
const MANIFEST = 'tools/inputs/manifest.json';

function fail(msg) {
	console.error('BOOTSTRAP FAIL: ' + msg);
	process.exit(1);
}

const argv = process.argv.slice(2);
const wantHashes = argv.includes('--hashes');
const wantBuild = argv.includes('--build');
if (!wantHashes && !wantBuild && !argv.includes('--check')) {
	fail('没有任何动作。用法：node tools/bootstrap.mjs --check | --hashes | --build [构建参数]');
}

if (!fs.existsSync(path.join(ROOT, MANIFEST))) {
	fail('找不到 ' + MANIFEST + ' —— 清单必须随仓库走（R-04）。');
}
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, MANIFEST), 'utf8'));

function globMatch(pattern, base) {
	const [head, ...rest] = pattern.split('/');
	const dir = path.join(ROOT, base, rest.length ? head : '');
	if (rest.length === 0) {
		// 末段是文件名（可带通配）
		if (!fs.existsSync(dir)) return false;
		if (fs.statSync(dir).isFile()) return true;
		const re = new RegExp('^' + head.replace(/\./g, '\\.').replace(/\*/g, '.*') + '$');
		return fs.readdirSync(dir).some((f) => re.test(f));
	}
	if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return false;
	return fs.readdirSync(dir).some((f) => globMatch([head, ...rest].slice(1).join('/') ? pattern.slice(pattern.indexOf('/') + 1) : pattern, path.join(base, head)));
}

function matchAny(base, patterns, isDir) {
	for (const p of patterns) {
		if (isDir) {
			const full = path.join(ROOT, base, p);
			if (fs.existsSync(full) && fs.statSync(full).isDirectory()) return p;
			continue;
		}
		if (globMatch(p, base)) return p;
	}
	return null;
}

const results = [];
let missing = 0;
for (const entry of manifest.inputs) {
	if (argv.includes('-SkipData') && ['iso','dec','hd'].includes(entry.id)) continue;
	const base = entry.path;
	let hit = null;
	// provide-or-env 的许可路径：环境变量也满足（如 CHIBI_GODOT_TEMPLATES 指向模板目录）
	const envName = entry.role === 'provide-or-env' ? (entry.id === 'templates' ? 'CHIBI_GODOT_TEMPLATES' : entry.id.toUpperCase()) : null;
	const envVal = (envName ? process.env[envName] : null) || (entry.id === 'templates' && process.env.APPDATA ? path.join(process.env.APPDATA,'Godot/export_templates/4.7.2.stable') : null);
	if (envVal && fs.existsSync(path.join(envVal, entry.requireFile || ''))) {
		results.push({ id: entry.id, role: entry.role, ok: true, hit: envName + '=' + envVal });
		continue;
	}
	let entryOk = fs.existsSync(path.join(ROOT, base));
	if (entryOk) {
		if (entry.requireFile) {
			hit = fs.existsSync(path.join(ROOT, base, entry.requireFile)) ? entry.requireFile : null;
			entryOk = hit !== null;
		} else if (entry.requireAny) {
			hit = matchAny(base, entry.requireAny, false);
			entryOk = hit !== null;
		} else if (entry.requireAnyDir) {
			hit = matchAny(base, entry.requireAnyDir, true);
			entryOk = hit !== null;
		}
	} else if (entry.kind === 'engine') {
		hit = 'engine exe';
		entryOk = fs.existsSync(path.join(ROOT, 'Godot_v4.7.2-stable_win64_console.exe'));
	}
	// dec：有快照则强校验（内容哈希，防外部工件悄悄变味——R-04）
	if (entry.id === 'dec' && entry.hashFile && fs.existsSync(path.join(ROOT, entry.hashFile)) && entryOk) {		const snapshot = fs.readFileSync(path.join(ROOT, entry.hashFile), 'utf8').trim().split(/\r?\n/);
		let mismatch = 0, checked = 0;
		for (const line of snapshot) {
			if (!line) continue;
			const sep = line.indexOf(' *');
			const hash = line.slice(0, sep);
			const rel = line.slice(sep + 2);
			const full = path.join(ROOT, base, rel);
			if (!fs.existsSync(full)) { mismatch += 1; console.error('BOOTSTRAP CHECK: dec/' + rel + ' 快照内缺失'); continue; }
			checked += 1;
			const actual = crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex');
			if (actual !== hash) { mismatch += 1; console.error('BOOTSTRAP CHECK: dec/' + rel + ' 哈希不符'); }
		}
		if (mismatch > 0) entryOk = false;
		else console.log('BOOTSTRAP CHECK: dec/ 快照校验通过（' + checked + ' 个文件）');
	}
	// Runtime inputs are versioned; production masters remain local.
	if (entry.id === 'art-masters' && entryOk) {
		const artHashFile = path.join(ROOT, entry.hashFile);
		if (!fs.existsSync(artHashFile)) {
			entryOk = false;
			console.error('BOOTSTRAP CHECK: 缺少 ' + entry.hashFile + '（运行 node tools/runtime_assets.mjs --write）');
		} else {
			const rows = fs.readFileSync(artHashFile, 'utf8').split(/\r?\n/).filter(Boolean).length;
			console.log('BOOTSTRAP CHECK: runtime 素材清单 ' + rows + ' 个文件；全量校验用 node tools/runtime_assets.mjs --check --hash');
		}
	}
	results.push({ id: entry.id, role: entry.role, ok: entryOk, hit });
	if (!entryOk) {
		missing += 1;
		console.error('BOOTSTRAP MISSING [' + entry.id + '] role=' + entry.role + ' path=' + base);
		console.error('  → ' + entry.hint);
	}
}

for (const r of results) {
	console.log('BOOTSTRAP ' + (r.ok ? 'OK  ' : 'MISS') + ' [' + r.id + '] ' + r.role + (r.hit ? ' (' + r.hit + ')' : ''));
}

if (wantHashes) {
	const dec = manifest.inputs.find((e) => e.id === 'dec');
	const base = path.join(ROOT, dec.path);
	const out = [];
	const walk = (d) => {
		for (const f of fs.readdirSync(d).sort()) {
			const full = path.join(d, f);
			if (fs.statSync(full).isDirectory()) walk(full);
			else if (!f.endsWith('.sha256')) out.push(crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex') + ' *' + path.relative(base, full).replaceAll('\\', '/'));
		}
	};
	walk(base);
	fs.mkdirSync(path.join(ROOT, 'tools/inputs'), { recursive: true });
	fs.writeFileSync(path.join(ROOT, dec.hashFile), out.join('\n') + '\n');
	console.log('BOOTSTRAP HASHES: ' + out.length + ' 个文件 → ' + dec.hashFile + '（提交该快照以固化 dec 的内容契约）');
	process.exit(0);
}

if (missing > 0) {
	fail(missing + ' 项输入缺失。按上面逐条落位，或从外部工件库恢复后重跑 --check。');
}
console.log('BOOTSTRAP OK: 全部输入就位 —— ' + (wantBuild ? '转发构建。' : manifest.build.entry));

if (wantBuild) {
	const args = argv.filter((a) => !a.startsWith('--build')).filter((a) => a !== '--check');
	const cmd = 'powershell.exe';
	const buildArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', manifest.build.entry, ...args];
	console.log('BOOTSTRAP BUILD: ' + cmd);
	const { spawnSync } = await import('node:child_process');
	const r = spawnSync(cmd, buildArgs, { stdio: 'inherit', shell: false, cwd: ROOT });
	if (r.error) console.error(r.error.message);
	process.exit(r.status ?? 1);
}
process.exit(0);
