import fs from 'node:fs';
fs.mkdirSync('_work/dec2', { recursive: true });
const list = ['JIMOU', 'MINIMAP', 'WAVE', 'INTERFAC', 'MAINBACK', 'OTHER', 'SPEC', 'OPTION', 'MOUSE', 'ICONHELP', 'COVER'];
for (const n of list) {
  const p = `_work/iso/SET/${n}.EXP`;
  if (!fs.existsSync(p)) { console.log('miss', n); continue; }
  const d = fs.readFileSync(p);
  const out = Buffer.from(d.map((b) => b ^ 0x22));
  fs.writeFileSync(`_work/dec2/${n}.txt`, out);
  console.log(n, d.length, '->', out.length, 'txt');
}
// 字符串预览（ASCII 安全）
for (const n of ['JIMOU', 'MINIMAP']) {
  const s = fs.readFileSync(`_work/dec2/${n}.txt`, 'utf8');
  console.log(`--- ${n} 全文 ---`);
  console.log(JSON.stringify(s));
}
const w = fs.readFileSync('_work/dec2/WAVE.txt', 'utf8');
console.log('--- WAVE 头 900 ---');
console.log(w.slice(0, 900));
