import fs from 'node:fs';
// 1) 字库特殊码表（10 个 Big5/GBK 双字节码）解码
const codes = [0x8FAA, 0x41E0, 0x90AA, 0xAC72, 0xD867, 0xEB68, 0xEE84, 0xAB64, 0xAB95, 0x8379];
const dec = new TextDecoder('gbk', { fatal: false });
console.log('--- 特殊码表（按存储顺序）---');
for (const c of codes) {
  const buf = Buffer.from([(c >> 8) & 0xff, c & 0xff]);
  console.log('0x' + c.toString(16).toUpperCase(), '->', JSON.stringify(dec.decode(buf)));
}
// 2) HZ.EXT / HZ.EDX 解码（XOR-0x22）
for (const n of ['HZ.EXT', 'HZ.EDX']) {
  const raw = fs.readFileSync('_work/iso/SET/' + n);
  const out = Buffer.from(raw.map((b) => b ^ 0x22));
  fs.writeFileSync('_work/dec2/' + n + '.txt', out);
  console.log('--- ' + n + ' (' + raw.length + 'B) 前 200 字符 ---');
  console.log(JSON.stringify(out.toString('utf8').slice(0, 200)));
}
// 3) INTERFAC 全量解析（count + 条目）
const txt = fs.readFileSync('_work/dec2/INTERFAC.txt', 'utf8');
const toks = txt.split(/\s+/).filter(Boolean);
const n = parseInt(toks[0], 10);
console.log('--- INTERFAC: 条目数 =', n, '---');
let i = 1;
const rows = [];
for (let k = 0; k < n && i < toks.length; k++) {
  rows.push(toks.slice(i, i = i + 5).join(' '));
}
for (const r of rows.slice(0, 46)) console.log('  ', r);
console.log('剩余 token:', toks.slice(i).join(' ').slice(0, 120));
