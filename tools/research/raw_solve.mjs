import fs from "node:fs";
import { header as medHeader, solveFile } from "../lib/medobjects.mjs";
const map = process.argv[2] || "chibil1";
const dir = "_work/iso/MEDS";
const name = fs.readdirSync(dir).find((f) => f.toLowerCase() === `${map}.med`.toLowerCase());
const buf = fs.readFileSync(`${dir}/${name}`);
const h = medHeader(buf);
const tail = new Map();
const tm = JSON.parse(fs.readFileSync("_work/dec/tailmap.json", "utf8"));
for (const k of ["tail0", "tail2", "tail4"]) for (const u of tm[k] || []) tail.set(u, Number(k.slice(4)));
const r = solveFile(buf, h.dataStart + h.layerBytes + 40, tail, h);
console.log("status:", r.status, "objects:", r.objects.length);
const used = r.objects.filter((o) => o.used);
console.log("used:", used.length, "unused slots:", r.objects.length - used.length);
const hist = {};
for (const o of used) hist[o.unit] = (hist[o.unit] || 0) + 1;
console.log("unit hist:", Object.keys(hist).map((k) => k + ":" + hist[k]).sort((a, b) => (+a.split(":")[0]) - (+b.split(":")[0])).join("  "));
// 未被解析/可疑记录（如果有）
const bad = used.filter((o) => o.unit === undefined || o.unit === null || o.unit < 0 || o.unit > 52);
console.log("suspicious:", bad.length, JSON.stringify(bad.slice(0, 5)));
// 导出 json 的对象直方图对比
const d = JSON.parse(fs.readFileSync(`godot/chibi_remake/data/${map}.json`, "utf8"));
const hist2 = {};
for (const o of d.objects) hist2[o.unit] = (hist2[o.unit] || 0) + 1;
console.log("json hist :", Object.keys(hist2).map((k) => k + ":" + hist2[k]).sort((a, b) => (+a.split(":")[0]) - (+b.split(":")[0])).join("  "));
