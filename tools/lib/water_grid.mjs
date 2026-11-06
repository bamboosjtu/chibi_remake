/**
 * water_grid — 从 MED 地形层导出"可通航水面"（重制版水军寻路用）。
 *
 * 磁贴 u16 布局（tools/lib/terrain_bake.mjs 头注释，CB.EXE FUN_0041db40）：
 *   `[15:12] class | [11:8] ground set | [7:4] sheet col | [3:0] sheet row`
 * **地形类型看 ground set（第 2 个 nibble），不是 class**：
 *   ground set = `Set\GROUND.EXP` 的记录号 → `LIB.LWC` 的对应帧（14 个地形组）：
 *   0 草/土、1 土/砾、2 土/浅砾、**3 水/土、4 青水/土**、5 混合、6 石砖墙、7 带草土崖、
 *   8 岩壁、9 城垛石墙、10 红土块、11 草块、12 木栅栏、13 道具
 *   （docs/10-battlefield.md「地形组」；2026-10-17 在本机用烘焙图逐格取色复核：
 *    set∈{3,4} 的格 92% 为蓝色水面，set∈{0,1,2} 的格 0% 为蓝）。
 *
 * 水面格 = **ground set ∈ {3,4}** 且 layer 1/2 无结构装饰（栈桥/栅栏压在水上时不当作可航行）。
 * 该网格：
 *   · 水军/运输船（46/47/48/49/52）按它寻路；
 *   · 陆军在 `terrainWalkable` 里被剔除（水面不再让步兵走过去）。
 */

export const WATER_GROUND_SETS = [3, 4];

/** @param {ReturnType<import('./medmap.mjs').parseMed>} mm */
export function waterCells(mm) {
  const out = new Uint8Array(mm.rows * mm.cols);
  for (let a = 0; a < mm.rows; a++) {
    for (let b = 0; b < mm.cols; b++) {
      const t0 = mm.layers[0][a][b];
      if (t0 === 0xffff) continue;
      const set = (t0 >> 8) & 0xf;
      if (!WATER_GROUND_SETS.includes(set)) continue;
      let clear = true;
      for (let L = 1; L < 3; L++) {
        if (mm.layers[L][a][b] !== 0xffff) { clear = false; break; }
      }
      if (clear) out[a * mm.cols + b] = 1;
    }
  }
  return out;
}

/** 统计：水面格数 / 与陆地相邻（有岸线）的格数。 */
export function waterStats(mm, cells) {
  let water = 0;
  let shore = 0;
  const isLand = (a, b) => {
    if (a < 0 || b < 0 || a >= mm.rows || b >= mm.cols) return false;
    const t0 = mm.layers[0][a][b];
    if (t0 === 0xffff) return false;
    const set = (t0 >> 8) & 0xf;
    if (set === 3 || set === 4) return false;
    const cls = (t0 >> 12) & 0xf;
    if (cls !== 0xf && cls !== 8 && cls !== 9) return false;
    for (let L = 1; L < 3; L++) {
      if (mm.layers[L][a][b] !== 0xffff) return false;
    }
    return true;
  };
  for (let a = 0; a < mm.rows; a++) {
    for (let b = 0; b < mm.cols; b++) {
      if (!cells[a * mm.cols + b]) continue;
      water++;
      if (isLand(a - 1, b) || isLand(a + 1, b) || isLand(a, b - 1) || isLand(a, b + 1)) shore++;
    }
  }
  return { water, shore };
}
