#!/usr/bin/env node
/**
 * hud_export — 从原版 BMP.LWC 与真机截图提取 HUD 素材。
 *
 * 来源与对应关系（全部经像素级模板匹配验证，2026-10-15）：
 *   BMP#42  640x48  完整顶栏（左簇 x0..230 / 红匾 x233..409 / 右簇 x395..640）
 *   BMP#36  24x408  左缘条（含 12 个按钮井位）
 *   BMP#40  157x408 右侧面板（小地图框 / 龙纹区 / 分隔金线 y101/279）
 *   BMP#31  640x24  底缘条
 *   资源图标  = BMP#42 内裁切（gold/wood/food/stone）
 *   左缘顶部蘑菇钮与 ▶ 钮 = 程序绘制（图库中不存在），从真机截图裁切
 *   命令图标样本 = BMP#165 第 1 格（40x120 系列 = 命令/选中图标，3 态各 40x40）
 *
 * 产出：
 *   _work/hud/ui1x/*.png     1× 原像素（过程产物）
 *   godot/chibi_remake/art/full/ui/*.png   ×4（realesrgan-x4plus-anime，1080p 用）
 *
 * 用法：node tools/hd/hud_export.mjs [--no-upscale]
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { readPng } from '../lib/pngread.mjs';
import { readFrames, extractFrame, readPal } from '../lib/lwc2png.mjs';
import { writeRgbaPng } from '../lib/lwc_sheet.mjs';

const ROOT = process.cwd();
const ONE = '_work/hud/ui1x';
const OUT = 'godot/chibi_remake/art/full/ui';
const RA = '_tools/realesrgan/realesrgan-ncnn-vulkan.exe';
const UPSCALE = !process.argv.includes('--no-upscale');

fs.mkdirSync(ONE, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });

const pal = readPal('_work/iso/RES/BATTLE.PAL');
const d6 = (v) => { const x = v >> 2; return ((x << 2) | (x >> 4)) & 0xff; };
const palDac = pal.map(([r, g, b]) => [d6(r), d6(g), d6(b)]);
const frames = new Map(readFrames('_work/iso/BMP/BMP.LWC', '_work/iso/BMP/BMP.IDX').map((f) => [f.i, f]));

function frameRgba(i) {
  const f = frames.get(i); const px = extractFrame(f);
  const rgba = Buffer.alloc(f.width * f.height * 4);
  for (let k = 0; k < f.width * f.height; k++) {
    const c = palDac[px[k]];
    rgba[k * 4] = c[0]; rgba[k * 4 + 1] = c[1]; rgba[k * 4 + 2] = c[2]; rgba[k * 4 + 3] = 255;
  }
  return { w: f.width, h: f.height, rgba };
}
function cropRgba(img, x, y, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) {
    const s = ((y + yy) * img.w + (x + xx)) * 4, d = (yy * w + xx) * 4;
    out[d] = img.rgba[s]; out[d + 1] = img.rgba[s + 1]; out[d + 2] = img.rgba[s + 2]; out[d + 3] = img.rgba[s + 3];
  }
  return { w, h, rgba: out };
}
function shotRgba(file) {
  const p = readPng(file);
  const rgba = Buffer.alloc(p.w * p.h * 4);
  for (let k = 0; k < p.w * p.h; k++) {
    rgba[k * 4] = p.rgb[k * 3]; rgba[k * 4 + 1] = p.rgb[k * 3 + 1]; rgba[k * 4 + 2] = p.rgb[k * 3 + 2]; rgba[k * 4 + 3] = 255;
  }
  return { w: p.w, h: p.h, rgba };
}

const exportsList = [];
function save(name, img) {
  writeRgbaPng(path.join(ONE, name + '.png'), img.w, img.h, img.rgba);
  exportsList.push(name);
}

const f42 = frameRgba(42);
save('hud_top_left', cropRgba(f42, 0, 0, 230, 48));
save('hud_top_right', cropRgba(f42, 395, 0, 245, 48));
save('hud_banner', cropRgba(f42, 233, 2, 176, 38));
// 中段平铺条：128x48 = fabric(0..15) + 金线(16) + navy(17..42) + 金线(43) + fabric(44..47)
{
  const top = cropRgba(f42, 410, 0, 128, 16).rgba;
  const bot = cropRgba(f42, 410, 44, 128, 4).rgba;
  const e0 = (16 * f42.w + 410) * 4;
  const edge = [f42.rgba[e0], f42.rgba[e0 + 1], f42.rgba[e0 + 2], 255];
  const navy = [0, 0, 40, 255];
  const tile = Buffer.alloc(128 * 48 * 4);
  for (let y = 0; y < 48; y++) for (let x = 0; x < 128; x++) {
    const d = (y * 128 + x) * 4;
    let c;
    if (y < 16) { const s = (y * 128 + x) * 4; c = [top[s], top[s + 1], top[s + 2], 255]; }
    else if (y === 16 || y === 43) c = edge;
    else if (y < 43) c = navy;
    else { const s = ((y - 44) * 128 + x) * 4; c = [bot[s], bot[s + 1], bot[s + 2], 255]; }
    tile[d] = c[0]; tile[d + 1] = c[1]; tile[d + 2] = c[2]; tile[d + 3] = c[3];
  }
  save('hud_bar_tile', { w: 128, h: 48, rgba: tile });
}
save('res_gold', cropRgba(f42, 26, 17, 30, 26));
save('res_wood', cropRgba(f42, 128, 17, 32, 26));
save('res_food', cropRgba(f42, 402, 17, 26, 26));
save('res_stone', cropRgba(f42, 512, 17, 30, 26));
save('hud_left', frameRgba(36));
save('hud_right', frameRgba(40));
save('hud_bottom', frameRgba(31));
save('cmd_boat', cropRgba(frameRgba(165), 0, 0, 40, 40));

const shot8 = shotRgba('\u8d64\u58c1\u7b80\u4f53\u4e2d\u6587\u5149\u76d8\u7248/capture/boot_008.png');
save('btn_special', cropRgba(shot8, 0, 165, 24, 18));   // 左缘顶部红钮（蘑菇图标）
save('btn_next', cropRgba(shot8, 0, 390, 24, 17));      // ▶ 钮

// 采样按钮底色，供 battle_view 里程序重绘 1..10 号钮用
function sample(img, x, y) {
  const o = (y * img.w + x) * 4;
  return [img.rgba[o], img.rgba[o + 1], img.rgba[o + 2]];
}
console.log('按钮底色采样（相邻无字处）：');
const red = sample(shot8, 3, 230);   // 红 "1" 钮左缘
const gray = sample(shot8, 3, 248);  // 灰 "2" 钮左缘
console.log(`  red  = rgb(${red.join(',')})  #${red.map((v) => v.toString(16).padStart(2, '0')).join('')}`);
console.log(`  gray = rgb(${gray.join(',')})  #${gray.map((v) => v.toString(16).padStart(2, '0')).join('')}`);

// ---- ×4 超分 ----
if (UPSCALE && fs.existsSync(RA)) {
  for (const name of exportsList) {
    const src = path.resolve(ONE, name + '.png');
    const dst = path.resolve(OUT, name + '.png');
    const r = spawnSync(path.resolve(RA), ['-i', src, '-o', dst, '-n', 'realesrgan-x4plus-anime', '-s', '4', '-f', 'png'],
      { cwd: path.resolve('_tools/realesrgan'), stdio: 'pipe' });
    if (r.status !== 0) {
      console.error(`超分失败 ${name}: status=${r.status} error=${r.error ? r.error.message : '-'} stderr=${r.stderr ? String(r.stderr).slice(0, 400) : '-'}`);
      process.exit(1);
    }
    console.log(`×4 ${name}.png`);
  }
} else {
  for (const name of exportsList) fs.copyFileSync(path.join(ONE, name + '.png'), path.join(OUT, name + '.png'));
  console.log(UPSCALE ? '（未找到 realesrgan，已按 1× 复制）' : '（--no-upscale：已按 1× 复制）');
}
console.log(`完成：${exportsList.length} 个素材 -> ${OUT}`);
