// 从 CB.EXE 提取 0x4b01b0 起的记录表（PE 段映射 + 原始字节分析）
import fs from 'node:fs';
const buf = fs.readFileSync('_work/iso/CB.EXE');
// PE 头
const peOff = buf.readUInt32LE(0x3c);
console.log('PE sig:', buf.toString('latin1', peOff, peOff + 4));
const nSec = buf.readUInt16LE(peOff + 6);
const optSize = buf.readUInt16LE(peOff + 20);
const imageBase = buf.readUInt32LE(peOff + 0x34);
const secOff = peOff + 24 + optSize;
const sections = [];
for (let i = 0; i < nSec; i++) {
  const o = secOff + i * 40;
  const name = buf.toString('latin1', o, o + 8).replace(/\0+$/, '');
  const va = buf.readUInt32LE(o + 12);
  const vsize = buf.readUInt32LE(o + 8);
  const raw = buf.readUInt32LE(o + 20);
  const rawSize = buf.readUInt32LE(o + 16);
  sections.push({ name, va, vsize, raw, rawSize });
  console.log(name, 'VA', va.toString(16), 'vsize', vsize.toString(16), 'raw@', raw.toString(16));
}
function vaToFile(va) {
  for (const s of sections) if (va >= s.va && va < s.va + s.vsize) return s.raw + (va - s.va);
  return -1;
}
const base = 0x4b01b0;
const off = vaToFile(base);
console.log('VA 0x4b01b0 -> file off', off.toString(16));
// 转储 0x180+ 字节，作为 int32 表打印
const N = 23;
for (let i = 0; i < N; i++) {
  const o = off + i * 0x20;
  const ints = [];
  for (let k = 0; k < 8; k++) ints.push(buf.readInt32LE(o + k * 4));
  const bytes = [];
  for (let k = 0; k < 32; k++) bytes.push(buf[o + k]);
  console.log(`slot ${String(i).padStart(2)}: ints=[${ints.join(',')}]  bytes=${bytes.map((b) => b.toString(16).padStart(2, '0')).join(' ')}`);
}
// 特殊槽 12..17 单资源价（DAT_004b0330 等 = slot12..17 的 +0x00）
console.log('--- 特殊槽（0x330 起，每 0x20 一跳）---');
for (let i = 12; i <= 17; i++) {
  const o = vaToFile(0x4b01b0 + i * 0x20);
  console.log(`slot ${i} first int:`, buf.readInt32LE(o), ' (DAT_004b0' + (0x330 + (i - 12) * 0x20).toString(16) + '?)');
}
