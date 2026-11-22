#!/usr/bin/env node
/**
 * ui_cmd_export —— 武将指令/计谋/阵法图标 → art/full/ui/cmd_atlas.png（×4）
 *
 * 来源（INTERFAC.EXP 解码 + BMP.LWC 逐帧目视，2026-10-16）：
 *   指令按钮 16130-16146 = BMP 帧 154..169（16 个；157=太极=计谋、159=将军=单挑、164=上船、169=运输）
 *   九计谋   16210-16218 = BMP 帧 98..106 （旗/靴/靴/靴/乱符/滚木/网/药葫芦/火）
 *   十阵法   16190-16199 = BMP 帧 113..122（一字长蛇阵 .. 十面埋伏阵）
 * 每帧 = 40×120（3 个 40×40 态纵向堆叠），本工具取全帧拼成 10 列图集，运行时取第一态 40×40。
 *
 * 用法：node tools/hd/ui_cmd_export.mjs [--no-upscale]
 */
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { readFrames, extractFrame, readPal } from '../lib/lwc2png.mjs';
import { writeRgbaPng } from '../lib/lwc_sheet.mjs';

const UPSCALE = !process.argv.includes('--no-upscale');
const RA = '_tools/realesrgan/realesrgan-ncnn-vulkan.exe';
const OUT1X = '_work/hud/cmd1x';
const OUT = 'godot/chibi_remake/art/full/ui';
fs.mkdirSync(OUT1X, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });

const FRAMES = [
  ...Array.from({ length: 9 }, (_, i) => 98 + i),   // 0..8   九计谋
  ...Array.from({ length: 10 }, (_, i) => 113 + i), // 9..18  十阵法
  ...Array.from({ length: 16 }, (_, i) => 154 + i), // 19..34 指令
];
const COLS = 10, CW = 44, CH = 124;

const pal = readPal('_work/iso/RES/BATTLE.PAL');
const d6 = (v) => { const x = v >> 2; return ((x << 2) | (x >> 4)) & 0xff; };
const palDac = pal.map(([r, g, b]) => [d6(r), d6(g), d6(b)]);
const frames = new Map(readFrames('_work/iso/BMP/BMP.LWC', '_work/iso/BMP/BMP.IDX').map((f) => [f.i, f]));

const rows = Math.ceil(FRAMES.length / COLS);
const W = COLS * CW, H = rows * CH;
const rgba = Buffer.alloc(W * H * 4, 0);
for (let n = 0; n < FRAMES.length; n++) {
  const f = frames.get(FRAMES[n]);
  if (!f || f.error) throw new Error(`帧 ${FRAMES[n]} 不可用`);
  const px = extractFrame(f);
  const gx = (n % COLS) * CW, gy = Math.floor(n / COLS) * CH;
  for (let y = 0; y < f.height; y++) {
    for (let x = 0; x < f.width; x++) {
      const v = px[y * f.width + x];
      if (v === 0) continue;
      const c = palDac[v];
      const o = ((gy + y) * W + gx + x) * 4;
      rgba[o] = c[0]; rgba[o + 1] = c[1]; rgba[o + 2] = c[2]; rgba[o + 3] = 255;
    }
  }
}
const atlas1x = `${OUT1X}/cmd_atlas.png`;
writeRgbaPng(atlas1x, W, H, rgba);
console.log(`1x atlas: ${atlas1x} (${W}x${H}, ${FRAMES.length} 帧)`);

const meta = { cols: COLS, cellW: CW, cellH: CH, frames: FRAMES, order: 'magic9+forms10+cmd16' };
fs.writeFileSync('_work/hud/cmd_atlas.json', JSON.stringify(meta, null, 2), 'utf8');

if (UPSCALE) {
  const out2 = `${OUT}/cmd_atlas.png`;
  const r = spawnSync(RA, ['-i', atlas1x, '-o', out2, '-s', '4', '-n', 'realesrgan-x4plus-anime', '-f', 'png'], { stdio: 'inherit' });
  if (r.status !== 0) throw new Error('realesrgan 失败');
  console.log(`HD atlas: ${out2}`);
} else {
  fs.copyFileSync(atlas1x, `${OUT}/cmd_atlas.png`);
  console.log(`(no-upscale) ${OUT}/cmd_atlas.png`);
}
