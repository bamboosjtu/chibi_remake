#!/usr/bin/env node
/**
 * exptable — read 三国赤壁's Set\*.EXP / .EXT / .EDX tables.
 *
 * CB.EXE 0x0041bb20 XORs every byte of these files with 0x22 as it loads them
 * (`*pbVar3 = bVar1 ^ 0x22;`), then FUN_0041b9f0 walks the plaintext with
 * whitespace-separated sscanf tokens. The files are therefore plain text at rest
 * only after the XOR.
 *
 * UNIT.EXP layout (verified against UNIT.LWC's size bands):
 *
 *   <unitCount>
 *   <id> <spriteName> <logicalName> <W>, <H>, <a>, <b>  <cols>, <rows>
 *   ...
 *
 * `cols * rows` is the number of consecutive UNIT.LWC frames belonging to that
 * unit, laid out in file order. Every unit record's frame count matches its size
 * band exactly.
 *
 * OTHER.EXP layout:
 *
 *   Unit <count>
 *   <subFrames>, <W>, <subHeight>, <frameIndex>   ...
 */
import fs from 'node:fs';

export const XOR_KEY = 0x22;

/** Read a .EXP/.EXT/.EDX table and return its decoded text. */
export function readExpText(file, xorKey = XOR_KEY) {
  const raw = fs.readFileSync(file);
  const dec = Buffer.from(raw.map((b) => b ^ xorKey));
  try { return new TextDecoder('gbk').decode(dec); } catch { return dec.toString('latin1'); }
}

/** Whitespace tokens with trailing commas stripped. */
function tokens(text) {
  return text.split(/\s+/).filter(Boolean).map((t) => t.replace(/,+$/, ''));
}

/**
 * Parse UNIT.EXP.
 * @returns {{count:number, units:Array<{id:number,spriteName:string,name:string,
 *   width:number,height:number,a:number,b:number,cols:number,rows:number,
 *   frameCount:number,firstFrame:number}>}}
 */
export function parseUnitExp(file) {
  const tok = tokens(readExpText(file));
  const count = Number(tok[0]);
  const units = [];
  let p = 1;
  let first = 0;
  for (let i = 0; i < count; i++) {
    const id = Number(tok[p++]);
    const spriteName = tok[p++];
    const name = tok[p++];
    const width = Number(tok[p++]);
    const height = Number(tok[p++]);
    const a = Number(tok[p++]);
    const b = Number(tok[p++]);
    const cols = Number(tok[p++]);
    const rows = Number(tok[p++]);
    const frameCount = cols * rows;
    units.push({ id, spriteName, name, width, height, a, b, cols, rows, frameCount, firstFrame: first });
    first += frameCount;
  }
  return { count, units, totalFrames: first, leftoverTokens: tok.length - p };
}

/**
 * Parse OTHER.EXP (the map-object / decoration bank descriptor).
 * @returns {{label:string, count:number, items:Array<{subFrames:number,width:number,
 *   subHeight:number,frameIndex:number}>}}
 */
export function parseOtherExp(file) {
  const tok = tokens(readExpText(file));
  const label = tok[0];
  const count = Number(tok[1]);
  const items = [];
  let p = 2;
  for (let i = 0; i < count; i++) {
    items.push({
      subFrames: Number(tok[p++]),
      width: Number(tok[p++]),
      subHeight: Number(tok[p++]),
      frameIndex: Number(tok[p++]),
    });
  }
  return { label, count, items, leftoverTokens: tok.length - p };
}

const invokedDirectly = process.argv[1]
  && import.meta.url === new URL(`file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`).href;
if (invokedDirectly) {
  const dir = process.argv[2] || 'iso/SET';
  const u = parseUnitExp(`${dir}/UNIT.EXP`);
  console.log(`UNIT.EXP: ${u.count} units, ${u.totalFrames} frames total, leftoverTokens=${u.leftoverTokens}`);
  console.log(' id  sprite     name     W   H   a  b  cols rows  frames  first..last');
  for (const x of u.units) {
    console.log(` ${String(x.id).padStart(2)}  ${x.spriteName.padEnd(9)} ${x.name.padEnd(8)} ${String(x.width).padStart(3)} ${String(x.height).padStart(3)} ${String(x.a).padStart(2)} ${String(x.b).padStart(2)} ${String(x.cols).padStart(4)} ${String(x.rows).padStart(4)} ${String(x.frameCount).padStart(6)}  ${x.firstFrame}..${x.firstFrame + x.frameCount - 1}`);
  }
  const o = parseOtherExp(`${dir}/OTHER.EXP`);
  console.log(`\nOTHER.EXP: label=${o.label} count=${o.count} leftoverTokens=${o.leftoverTokens}`);
  for (const x of o.items) console.log(`  frame ${String(x.frameIndex).padStart(2)}: ${x.width}x${x.subHeight} x${x.subFrames} = ${x.width}x${x.subHeight * x.subFrames}`);
}
