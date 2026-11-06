export function buildNavigation(mm, objects) {
  const terrainWalk = new Array(mm.rows * mm.cols).fill(1);
  // 放置用（**建造**）：与移动同底线（结构物上都不能走也不能建）。
  const walk = new Array(mm.rows * mm.cols).fill(1);
  for (let a = 0; a < mm.rows; a++) {
    for (let b = 0; b < mm.cols; b++) {
      const t0 = mm.layers[0][a][b];
      const hi = (t0 >> 12) & 0xf;
      let passable = t0 !== 0xffff && (hi === 0xf || hi === 8 || hi === 9);
      if (passable) {
        for (let L = 1; L < 3; L++) {
          if (mm.layers[L][a][b] !== 0xffff) { passable = false; break; } // 崖壁/栅栏/城墙
        }
      }
      terrainWalk[a * mm.cols + b] = passable ? 1 : 0;
      walk[a * mm.cols + b] = passable ? 1 : 0;
    }
  }
  // ---------- 1c. 城门的基础通道（运行时 nav/automatic_gates 控制开闭） ----------
  // 城门（unit 16/17）= 拱门通道：锚格 3×3 内、L0 类 ∈ {f,8,9} 的地形封格打开；
  // 城墙其余段、栅栏、崖壁照旧阻挡。运行时 nav.rebuild_buildings 同步跳过城门占地。
  // 连通性已验证：r=1（3×3）即打通 chibil1 城内外（区域 1050→16771 格，两铁矿均可达）。
  let gateOpen = 0;
  for (const ob of objects) {
    if (ob.unit !== 16 && ob.unit !== 17) continue;
    for (let da = -1; da <= 1; da++) {
      for (let db = -1; db <= 1; db++) {
        const a = ob.A + da, b = ob.B + db;
        if (a < 0 || b < 0 || a >= mm.rows || b >= mm.cols) continue;
        const t0 = mm.layers[0][a][b];
        const hi = (t0 >> 12) & 0xf;
        if (!(t0 !== 0xffff && (hi === 0xf || hi === 8 || hi === 9))) continue;
        const i2 = a * mm.cols + b;
        if (!terrainWalk[i2]) gateOpen++;
        terrainWalk[i2] = 1;
        walk[i2] = 1;
      }
    }
  }

  // static buildings block their cell too
  for (const ob of objects) {
    if (ob.unit <= 26) walk[ob.A * mm.cols + ob.B] = 0;
  }

  // ---------- 1d. 地形饰物表（OTHER 帧 7 树/粮；原版 FUN_00444960）----------
  // 供运行时采集：树=木、粮堆=粮。相位 = (class&3)*2 + (class∈8..0xB?1:0)。
  // 相位 0 = 松树（木）、2 = 粮堆（粮）；104（相位 4）全库仅 1 格。
  const decor = [];
  for (let a = 0; a < mm.rows; a++) {
    for (let b = 0; b < mm.cols; b++) {
      const t0 = mm.layers[0][a][b];
      if (t0 === 0xffff) continue;
      const cls = (t0 >> 12) & 0xf;
      if (cls === 0xf) continue;
      const phase = (cls & 3) * 2 + ((cls >= 8 && cls <= 0xb) ? 1 : 0);
      if (phase > 5) continue;
      decor.push([a, b, phase]);
    }
  }


  return {terrainWalk, walk, decor, gateOpen};
}
