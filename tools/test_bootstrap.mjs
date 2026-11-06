#!/usr/bin/env node
// REQ-004 回归夹具：bootstrap 的"不许猜"契约。
//   · 输入齐 → --check 退出 0
//   · 缺项 → 非零 + 逐条 BOOTSTRAP MISSING + 落位指引
//   · --hashes 生成 dec 快照；内容被改 → --check 非零
//   · 构建参数不合法/不存在 → 非零（绝不静默装作构建成功）
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const REPO = process.cwd();
const BOOT = path.join(REPO, 'tools/bootstrap.mjs');
const sandbox = path.join(REPO, '_work/architecture-tests/bootstrap-sandbox');
fs.rmSync(sandbox, { recursive: true, force: true });
fs.mkdirSync(sandbox, { recursive: true });

// 复制仓库侧的 bootstrap + manifest，沙箱内摆结果目录结构
fs.copyFileSync(BOOT, path.join(sandbox, 'bootstrap.mjs'));
fs.mkdirSync(path.join(sandbox, 'tools/inputs'), { recursive: true });
fs.copyFileSync(path.join(REPO, 'tools/inputs/manifest.json'), path.join(sandbox, 'tools/inputs/manifest.json'));

// 引擎桩：沙箱里放一个假 Godot exe，避免依赖本机安装
fs.writeFileSync(path.join(sandbox, 'Godot_v4.7.2-stable_win64_console.exe'), 'stub');

function fabricate() {
	fs.mkdirSync(path.join(sandbox, 'tools/inputs'), { recursive: true });
	fs.mkdirSync(path.join(sandbox, '_work/iso/MEDS'), { recursive: true });
	fs.writeFileSync(path.join(sandbox, '_work/iso/MEDS/CHIBIC1.MED'), 'x');
	fs.mkdirSync(path.join(sandbox, '_work/dec'), { recursive: true });
	fs.writeFileSync(path.join(sandbox, '_work/dec/anim_clips.json'), '{}');
	fs.writeFileSync(path.join(sandbox, '_work/dec/battle_parsed.json'), '{}');
	fs.writeFileSync(path.join(sandbox, '_work/dec/UNIT.EXP.txt'), 'x');
	fs.mkdirSync(path.join(sandbox, '_work/hd/terrain4'), { recursive: true });
	fs.writeFileSync(path.join(sandbox, '_work/hd/terrain4/a.png'), 'x');
	fs.mkdirSync(path.join(sandbox, 'godot/chibi_remake/art/production'), { recursive: true });
	fs.writeFileSync(path.join(sandbox, 'godot/chibi_remake/art/production/catalog.json'), '{}');
	fs.mkdirSync(path.join(sandbox, 'godot/chibi_remake/art/full/units'), { recursive: true });
	fs.writeFileSync(path.join(sandbox, 'godot/chibi_remake/art/full/units/stub.png'), 'x');
	// 模板目录由本机的 _work/art-v1-build 提供（只读借用），engine exe 是桩
}

fabricate();
fs.writeFileSync(path.join(sandbox,'tools/inputs/runtime_assets.sha256'),'fixture\n');
function run(args) {
	const r = spawnSync(process.execPath, ['bootstrap.mjs', ...args], {
		cwd: sandbox, encoding: 'utf8',
		env: { ...process.env, CHIBI_GODOT_TEMPLATES: path.join(REPO, '_tools/template_stub') },
	});
	return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}

// 沙箱用 env 提供模板（provide-or-env 的合法路径）
fs.mkdirSync(path.join(REPO, '_tools/template_stub'), { recursive: true });
fs.writeFileSync(path.join(REPO, '_tools/template_stub/windows_release_x86_64.exe'), 'stub');

let ok = true;
const expect = (cond, msg) => { if (!cond) { ok = false; console.error('TEST FAIL: ' + msg); } };

// 1) 全就位 → 0
let r = run(['--check']);
expect(r.code === 0, '输入齐全应为 0：' + r.out);
expect(r.out.includes('BOOTSTRAP OK: 全部输入就位'), '应有全绿行');

// 2) 缺 hd → 非零 + MISSING 行带指引
fs.rmSync(path.join(sandbox, '_work/hd'), { recursive: true, force: true });
r = run(['--check']);
expect(r.code !== 0, '缺 hd 应非零');
expect(r.out.includes('BOOTSTRAP MISSING [hd]'), '应点名 hd：' + r.out);
expect(r.out.includes('HD 源图'), '应带落位指引');

// 3) --hashes 生成 dec 快照
fs.mkdirSync(path.join(sandbox, '_work/hd/terrain4'), { recursive: true });
fs.writeFileSync(path.join(sandbox, '_work/hd/terrain4/a.png'), 'x');
r = run(['--hashes']);
expect(r.code === 0, '--hashes 应成功：' + r.out);
const snapPath = path.join(sandbox, 'tools/inputs/dec.sha256');
expect(fs.existsSync(snapPath), '应生成 dec.sha256');
// 4) 快照在场时篡改 dec 内容 → 校验拒绝
fs.writeFileSync(path.join(sandbox, '_work/dec/battle_parsed.json'), '{"tampered":true}');
r = run(['--check']);
expect(r.code !== 0, 'dec 被篡改应非零');
expect(r.out.includes('哈希不符'), '应报哈希不符：' + r.out);
// 5) 恢复内容 → 又全绿
fs.writeFileSync(path.join(sandbox, '_work/dec/battle_parsed.json'), '{}');
r = run(['--check']);
expect(r.code === 0, '恢复后应为 0：' + r.out);

if (process.platform === 'win32') {
 const manifestPath=path.join(sandbox,'tools/inputs/manifest.json');
 const manifest=JSON.parse(fs.readFileSync(manifestPath));
 manifest.build.entry='tools/build stub.ps1';fs.writeFileSync(manifestPath,JSON.stringify(manifest));
 fs.writeFileSync(path.join(sandbox,manifest.build.entry),"if ($args.Count -ne 2 -or $args[0] -ne '-SkipData' -or $args[1] -ne 'space argument') { exit 9 }; exit 0");
 r=run(['--build','-SkipData','space argument']);expect(r.code===0,'real build argv forwarding: '+r.out);
}

// A clone using committed runtime data needs no original extraction workspace.
fs.rmSync(path.join(sandbox,'_work/iso'),{recursive:true,force:true});
fs.rmSync(path.join(sandbox,'_work/dec'),{recursive:true,force:true});
fs.rmSync(path.join(sandbox,'_work/hd'),{recursive:true,force:true});
r=run(['--check','-SkipData']);expect(r.code===0,'runtime clone must not require research extraction inputs: '+r.out);

// 6) 清单不在 → 拒绝（不给"猜"的机会）
fs.rmSync(path.join(sandbox, 'tools/inputs/manifest.json'));
r = run(['--check']);
expect(r.code !== 0 && r.out.includes('找不到'), '缺清单应失败并说明');

if (!ok) { console.error('BOOTSTRAP TEST FAILED'); process.exit(1); }
console.log('BOOTSTRAP TEST PASS: check green/red, hashes verify, tamper rejected, manifest required');
