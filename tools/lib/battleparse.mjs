#!/usr/bin/env node
/**
 * battleparse — BATTLE.EXP 五段解析仿真器（严格复刻 CB.EXE FUN_00446380 的读取行为）。
 *
 * 机制（REA 实证）：
 *   - 游标推进 FUN_0041b9f0：按 ' '/'\t' 分词，跳"本次 sscanf 成功转换的字段数"个 token；
 *     每次调用先跳过开头的空格/Tab；token 内可含逗号/换行。
 *   - sscanf 语义（msvcrt）：格式内空白 = 跳过 0+ 空白；%d = 跳过空白后读 [+-]?数字；
 *     %s = 跳过空白后读到下一个空白。遇转换失败即返回已完成数。
 *   - 五段（按顺序）：
 *     A: [n] 行 × "%s %d %d %d"          -> 34 个 (名+3整数，19B 结构)
 *     B: [n] 行 × "%d %s" + 13×"%d"      -> 15 字段（56B 结构）
 *     C: [n] 行 × "%d %s" + 15×"%d"      -> 17 字段（续填同一数组）
 *     D: [n] 行 × 8×"%d"                 -> 32B 结构（生产/造价表！）
 *     E: [n] 行 × "%s" + 5×"%d"          -> 44B 结构
 *
 * 用法：node tools/lib/battleparse.mjs [BATTLE.EXP] [out.json]
 */
import fs from 'node:fs';
import path from 'node:path';
import { readExpText } from './exptable.mjs';

const src = process.argv[2] || '_work/iso/SET/BATTLE.EXP';
const outPath = process.argv[3] || '_work/dec/battle_parsed.json';
const text = readExpText(src);
const LEN = text.length;

class Walker {
  constructor(s) { this.s = s; this.pos = 0; }
  skipSp() { while (this.pos < LEN && (this.s[this.pos] === ' ' || this.s[this.pos] === '\t')) this.pos++; }
  /** C-like whitespace skip (for sscanf directives) */
  skipCSp() { while (this.pos < LEN && /\s/.test(this.s[this.pos])) this.pos++; }
  /** advance cursor by n tokens, mirroring FUN_0041b9f0 */
  advance(n) {
    this.skipSp();
    let state = true;
    while (n !== 0 && this.pos < LEN) {
      const c = this.s[this.pos];
      const sep = (c === ' ' || c === '\t');
      if (sep && state) { state = false; n--; }
      if (!sep) state = true;
      this.pos++;
    }
  }
  /** emulate one sscanf call from the current cursor; returns {vals, ret} */
  sscanf(fields) {
    const start = this.pos;
    const vals = [];
    let ret = 0;
    for (const f of fields) {
      this.skipCSp();
      if (this.pos >= LEN) break;
      if (f === 'd') {
        const m = /^[+-]?\d+/.exec(this.s.slice(this.pos, this.pos + 24));
        if (!m) break;
        vals.push(Number(m[0]));
        this.pos += m[0].length;
        ret++;
      } else { // %s
        if (/\s/.test(this.s[this.pos])) break;
        let p = this.pos;
        while (p < LEN && !/\s/.test(this.s[p])) p++;
        vals.push(this.s.slice(this.pos, p));
        this.pos = p;
        ret++;
      }
    }
    this.pos = start; // sscanf position is discarded; walker advances by tokens
    return { vals, ret };
  }
  readInt() {
    const { vals, ret } = this.sscanf(['d']);
    this.advance(ret);
    return vals.length ? vals[0] : null;
  }
  readRow(fields) {
    const { vals, ret } = this.sscanf(fields);
    this.advance(ret);
    return vals;
  }
}

const w = new Walker(text);
const out = { A: [], B: [], C: [], D: [], E: [] };

const nA = w.readInt();
for (let i = 0; i < nA; i++) out.A.push(w.readRow(['s', 'd', 'd', 'd']));
const nB = w.readInt();
for (let i = 0; i < nB; i++) out.B.push(w.readRow(['d', 's', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd']));
const nC = w.readInt();
for (let i = 0; i < nC; i++) out.C.push(w.readRow(['d', 's', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd', 'd']));
const nD = w.readInt();
for (let i = 0; i < nD; i++) out.D.push(w.readRow(['d', 'd', 'd', 'd', 'd', 'd', 'd', 'd']));
const nE = w.readInt();
for (let i = 0; i < nE; i++) out.E.push(w.readRow(['s', 'd', 'd', 'd', 'd', 'd']));

console.log(`counts: A=${nA} B=${nB} C=${nC} D=${nD} E=${nE}`);
console.log('--- A (first 6 & last 3) ---');
for (const r of [...out.A.slice(0, 6), ...out.A.slice(-3)]) console.log('  ', JSON.stringify(r));
console.log('--- D (cost table) ---');
for (const r of out.D) console.log('  ', r.join(', '));
console.log('--- E (first 4) ---');
for (const r of out.E.slice(0, 4)) console.log('  ', JSON.stringify(r));
console.log('--- B/C (first 2 each) ---');
for (const r of out.B.slice(0, 2)) console.log('  B', JSON.stringify(r).slice(0, 140));
for (const r of out.C.slice(0, 2)) console.log('  C', JSON.stringify(r).slice(0, 140));

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 1));
console.log(`\nwrote ${outPath}`);
