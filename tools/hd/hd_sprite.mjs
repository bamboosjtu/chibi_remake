#!/usr/bin/env node
/**
 * hd_sprite — AI 超分的前后处理（透明素材专用）。
 *
 * 流程（单位精灵/任何索引透明图）：
 *   1) dilate  把 idx0 透明像素用邻近不透明颜色向外扩散填充
 *              （避免超分模型在透明区产生暗色污染 / 边缘黑边）
 *   2) 用 realesrgan-ncnn-vulkan 对填充后的 RGB 图超分（anime 模型）
 *   3) compose 用原图掩码 (idx != 0) 最近邻放大，合成 RGBA 输出
 *
 * 用法（仓库根目录）：
 *   node tools/hd/hd_sprite.mjs dilate  <inDir> <outDir> [passes=3]
 *   node tools/hd/hd_sprite.mjs compose <origDir> <upscaledDir> <outDir>
 */
import fs from 'node:fs';
import path from 'node:path';
import { readPng } from '../lib/pngread.mjs';
import { writeRgbPng, writeRgbaPng } from '../lib/lwc_sheet.mjs';

const [mode, a1, a2, a3] = process.argv.slice(2);
if (!mode) {
  console.error('usage: node tools/hd/hd_sprite.mjs dilate <inDir> <outDir> [passes] | compose <origDir> <upscaledDir> <outDir>');
  process.exit(2);
}

function dilate(inDir, outDir, passes = 3) {
  fs.mkdirSync(outDir, { recursive: true });
  let n = 0;
  for (const f of fs.readdirSync(inDir)) {
    if (!f.endsWith('.png')) continue;
    const d = readPng(path.join(inDir, f));
    const w = d.w, h = d.h;
    if (!d.idx) { writeRgbPng(path.join(outDir, f), w, h, d.rgb); n++; continue; }
    const rgb = Buffer.from(d.rgb);
    const filled = Uint8Array.from(d.idx, (v) => (v !== 0 ? 1 : 0));
    for (let p = 0; p < passes; p++) {
      const add = [];
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const i = y * w + x;
          if (filled[i]) continue;
          let r = 0, g = 0, b = 0, c = 0;
          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
              const nx = x + dx, ny = y + dy;
              if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
              const j = ny * w + nx;
              if (!filled[j]) continue;
              r += rgb[j * 3]; g += rgb[j * 3 + 1]; b += rgb[j * 3 + 2]; c++;
            }
          }
          if (c > 0) add.push([i, (r / c) | 0, (g / c) | 0, (b / c) | 0]);
        }
      }
      for (const [i, r, g, b] of add) {
        rgb[i * 3] = r; rgb[i * 3 + 1] = g; rgb[i * 3 + 2] = b;
        filled[i] = 1;
      }
    }
    writeRgbPng(path.join(outDir, f), w, h, rgb);
    n++;
  }
  console.log(`dilated ${n} files -> ${outDir}`);
}

function compose(origDir, upDir, outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  let n = 0;
  for (const f of fs.readdirSync(origDir)) {
    if (!f.endsWith('.png')) continue;
    const up = path.join(upDir, f);
    if (!fs.existsSync(up)) continue;
    const d = readPng(path.join(origDir, f));
    const u = readPng(up);
    // ARCH-012：以前这里**静默**降级成 3 通道 RGB。Godot 把 RGB 当全不透明导入，
    // 而未膨胀的背景是黑色 → 每格变成「黑底 + 中间一个精灵」= 黑块。
    // 触发条件就是 origDir 传错（把 dilate 的 RGB 输出当成了带调色板的原图），
    // 而旧代码不会报错。现在直接失败，逼调用方传原始索引目录。
    if (!d.idx) {
      throw new Error(
        `compose: ${f} 在 origDir 里没有调色板索引（readPng 返回 idx=null）。\n` +
        `  origDir = ${origDir}\n` +
        `  这通常是误把 dilate 的 **RGB** 输出当成了原始索引图。\n` +
        `  compose 必须用 unit2png / godot_export 产出的 colour-type-3（带 tRNS）图集。\n` +
        `  继续下去会静默产出全不透明的黑底图。`);
    }
    // ARCH-012：倍率必须是整数且尺寸严格成比例，否则 alpha 掩码会错位
    const k = u.w / d.w;
    if (!Number.isInteger(k) || k < 1 || u.h !== d.h * k) {
      throw new Error(
        `compose: ${f} 尺寸不成整数倍 —— 原始 ${d.w}x${d.h}，放大 ${u.w}x${u.h}（k=${k}）。\n` +
        `  alpha 掩码会因此错位，必须先修正上采样尺寸。`);
    }
    const rgba = Buffer.alloc(u.w * u.h * 4);
    for (let y = 0; y < u.h; y++) {
      const oy = Math.min(d.h - 1, Math.floor(y / k));
      for (let x = 0; x < u.w; x++) {
        const ox = Math.min(d.w - 1, Math.floor(x / k));
        const s = (y * u.w + x) * 3;
        const o = (y * u.w + x) * 4;
        rgba[o] = u.rgb[s];
        rgba[o + 1] = u.rgb[s + 1];
        rgba[o + 2] = u.rgb[s + 2];
        rgba[o + 3] = d.idx[oy * d.w + ox] !== 0 ? 255 : 0;
      }
    }
    writeRgbaPng(path.join(outDir, f), u.w, u.h, rgba);
    n++;
  }
  console.log(`composed ${n} RGBA files -> ${outDir}`);
}

if (mode === 'dilate') dilate(a1, a2, a3 ? Number(a3) : 3);
else if (mode === 'compose') compose(a1, a2, a3);
else { console.error('unknown mode'); process.exit(2); }
