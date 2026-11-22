import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export function encodingIssue(bytes) {
  const bom = bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf;
  if ([...bytes].some(byte => byte > 127) && !bom) return 'non-ASCII PowerShell requires UTF-8 BOM for Windows PowerShell 5.1';
  try { new TextDecoder('utf-8', {fatal:true}).decode(bytes); } catch { return 'invalid UTF-8'; }
  return null;
}
if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const files=execFileSync('git',['ls-files','-z','*.ps1'],{encoding:'utf8'}).split('\0').filter(Boolean);
  for (const file of files) { const issue=encodingIssue(fs.readFileSync(file)); if (issue) throw Error(file+': '+issue); }
  console.log('POWERSHELL ENCODING PASS '+files.length+' scripts');
}
