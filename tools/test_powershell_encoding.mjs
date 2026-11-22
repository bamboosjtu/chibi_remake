import assert from 'node:assert/strict';
import {encodingIssue} from './powershell_encoding.mjs';
assert.equal(encodingIssue(Buffer.from('Write-Output "ASCII"')),null);
assert.match(encodingIssue(Buffer.from('Write-Output "中文|正由另一进程"')),/BOM/);
assert.equal(encodingIssue(Buffer.from('\ufeffWrite-Output "中文|正由另一进程"')),null);
assert.match(encodingIssue(Buffer.from([0xef,0xbb,0xbf,0xff])),/invalid UTF-8/);
console.log('POWERSHELL ENCODING NEGATIVE PASS missing BOM / malformed UTF-8');
