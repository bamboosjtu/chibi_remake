import fs from "node:fs";
import { parseMed } from "../lib/medmap.mjs";
const map = process.argv[2] || "chibil1";
const dir = "_work/iso/MEDS";
const name = fs.readdirSync(dir).find((f) => f.toLowerCase() === `${map}.med`.toLowerCase());
console.log("MED:", name);
const buf = fs.readFileSync(`${dir}/${name}`);
const mm = parseMed(buf);
const gates = [[13, 173, "gate1(unit17@572,1837)"], [32, 175, "gate2(unit16@1408,1859)"], [33, 213, "gate3(unit17@1452,2277)"], [13, 214, "gate4(unit16@550,2288)"]];
for (const [ca, cb, label] of gates) {
  console.log("=== " + label + " (窗口 a=" + (ca - 5) + ".." + (ca + 5) + " b=" + (cb - 6) + ".." + (cb + 6) + ") ===");
  for (let a = ca - 5; a <= ca + 5; a++) {
    const l0 = [], l1 = [], l2 = [], ps = [];
    for (let b = cb - 6; b <= cb + 6; b++) {
      const t0 = mm.layers[0][a][b];
      const hi = (t0 >> 12) & 0xf;
      let pass = t0 !== 0xffff && (hi === 0xf || hi === 8 || hi === 9);
      if (pass) for (let L = 1; L < 3; L++) if (mm.layers[L][a][b] !== 0xffff) { pass = false; break; }
      l0.push(hi.toString(16) + ":" + t0.toString(16).padStart(4, "0"));
      const t1 = mm.layers[1][a][b], t2 = mm.layers[2][a][b];
      l1.push(t1 === 0xffff ? "----" : t1.toString(16).padStart(4, "0"));
      l2.push(t2 === 0xffff ? "----" : t2.toString(16).padStart(4, "0"));
      ps.push(pass ? "·" : "#");
    }
    console.log("a" + String(a).padStart(3) + " L0 " + l0.join(" "));
    console.log("      L1 " + l1.join(" "));
    console.log("      L2 " + l2.join(" "));
    console.log("      P  " + ps.join(" "));
  }
}
