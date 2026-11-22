import fs from 'node:fs';
const dir = '_work/iso/SET';
const files = fs.readdirSync(dir).filter((f) => /\.(EXP|EXT)$/i.test(f));
for (const f of files) {
  const raw = fs.readFileSync(dir + '/' + f);
  const out = Buffer.from(raw.map((b) => b ^ 0x22));
  const s = out.toString('latin1');
  // 找含 "400" 的行段（数字表特征）
  if (/50\D{1,4}50\D{1,4}400/.test(s) || /400/.test(s)) {
    const i = s.search(/50\D{1,4}50\D{1,4}400/);
    if (i >= 0) {
      console.log('=== ' + f + ' @' + i + ' ===');
      console.log(JSON.stringify(s.slice(Math.max(0, i - 120), i + 240)));
    }
  }
}
console.log('--- 若上面没有，试 0x46 键 ---');
for (const f of files) {
  const raw = fs.readFileSync(dir + '/' + f);
  const out = Buffer.from(raw.map((b) => b ^ 0x46));
  const s = out.toString('latin1');
  const i = s.search(/50\D{1,4}50\D{1,4}400/);
  if (i >= 0) {
    console.log('=== ' + f + ' (xor46) @' + i + ' ===');
    console.log(JSON.stringify(s.slice(Math.max(0, i - 120), i + 240)));
  }
}
